//flaten contract for polygon...
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
 
contract NavadaPreSale is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
 
    mapping(address => uint256) public tokensBought;
 
    address public multiSignTreasuryWallet;
    IERC20 immutable NavadaToken;
    uint256 public tokenPrice; // Token Price is per POL eg. 1POL=20 Navada and must be with proper 18 decimals format
 
    AggregatorV3Interface public priceFeed; // Chainlink price feed;
    uint256 immutable priceStaleThreshold = 1 hours;
    uint256 public minThresholdLimit; // Minimum buy value in POL
 
    event TokensPurchased(address indexed buyer, uint256 amount);
    event FinnityTokenAddressUpdated(address indexed newAddress);
    event AggregatorPairUpdated(address indexed newPairAddress);
    event minThresholdUpdated(uint256 indexed newMinThresholdLimit);
    event TokenPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokensWithdrawn(address indexed admin, uint256 amount);
    event POLWithdrawn(address indexed admin, uint256 amount);
    event TreasuryWalletUpdated(address indexed newWallet);
 
    // _tokenPrice should be in 18 decimals format.
    // _minBuyValueInUSDT value should be in usdt with 6 decimals
    constructor(
        uint256 _tokenPrice,
        address multiSigWallet,
        uint256 _minThresholdLimit,
        address _NavadaToken
    ) Ownable(multiSigWallet) {
        NavadaToken = IERC20(_NavadaToken); //NavadaToken Contract Address
        tokenPrice = _tokenPrice;
        multiSignTreasuryWallet = multiSigWallet;
        minThresholdLimit = _minThresholdLimit;
        priceFeed = AggregatorV3Interface(0x001382149eBa3441043c1c66972b4772963f5D43); // USDT/POL Pair Price Feed Address
    }
 
    function getUSDTPriceInPOL() public view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data"); // Ensure valid price
        require(block.timestamp - updatedAt <= priceStaleThreshold,"Price data is stale");
        return uint256(price); // Price of 1 USDT in POL
    }
 
    function updateTreasuryWallet(address _multiSigWallet) external onlyOwner {
        require(_multiSigWallet != address(0), "Invalid Treasury Wallet");
        require(multiSignTreasuryWallet != _multiSigWallet, "Use Diff. Wallet");
        multiSignTreasuryWallet = _multiSigWallet;
        emit TreasuryWalletUpdated(_multiSigWallet);
    }
 
    function buyTokens() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Must send some POL");
        uint256 price = getUSDTPriceInPOL();
        uint256 POLAmountInUSDT = (msg.value * 1e18) / price ;
        require(
            POLAmountInUSDT >= (minThresholdLimit * 1e12),
            "Less Than Threshold"
        );
        uint256 NavadaTokQty = (POLAmountInUSDT * tokenPrice)/1e18;
        require(NavadaToken.balanceOf(address(this)) >= NavadaTokQty,"Insufficient Navada bal");
 
        NavadaToken.safeTransfer(msg.sender, NavadaTokQty);
 
        (bool success, ) = payable(multiSignTreasuryWallet).call{
            value: msg.value
        }("");
        require(success, "Failed to transfer POL");
 
        tokensBought[msg.sender] = tokensBought[msg.sender] + NavadaTokQty;
        emit TokensPurchased(msg.sender, NavadaTokQty);
    }



    function buyTokens() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Must send some POL");
        uint256 POLPriceInUSDT = getLatestPrice(); // price in 8 decimal format
        // Calculate the equivalent amount of USDT
        uint256 POLAmountInUSDT = (POLPriceInUSDT * msg.value);
        // Calculate the amount of Navada tokens to send
        uint256 navadaTokQty = (POLAmountInUSDT * tokenPrice)/1e26;
        require(navadaTokQty > 0, "Invalid Purchase");
        require(
            navadaToken.balanceOf(address(this)) >= navadaTokQty,
            "Insufficent Tokens"
        );

        navadaToken.safeTransfer(msg.sender, navadaTokQty);
        (bool success, ) = payable(multiSignTreasuryWallet).call{
            value: msg.value
        }("");
        require(success, "Failed to transfer ETH");

        tokensBought[msg.sender] = tokensBought[msg.sender] + navadaTokQty;
        emit TokensPurchased(msg.sender, navadaTokQty);
    }
 
    function withdrawProfit() external onlyOwner {
        uint256 totalBalance = address(this).balance;
        (bool sent, ) = multiSignTreasuryWallet.call{value: totalBalance}("");
        if (sent == false) revert("POL Transfer Failed");
    }
 

 
    function withdrawTokens(address tokenAddress, uint256 amount)
        external
        onlyOwner
    {
        require(amount > 0, "Amount must be greater than 0");
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) > 0, "Insufficient token");
        if (token.balanceOf(address(this)) < amount) {
            amount = token.balanceOf(address(this));
        }
        token.safeTransfer(multiSignTreasuryWallet, amount);
        emit TokensWithdrawn(msg.sender, amount); // Emit event
    }
 
    // Token Price must be in 18 decimals.
    function setTokenPrice(uint256 _newTokenPrice) external onlyOwner {
        require(_newTokenPrice > 0, "Price must be greater than 0");
        uint256 oldTokenPrice = tokenPrice; // Cache the old token price
        tokenPrice = _newTokenPrice;
        emit TokenPriceUpdated(oldTokenPrice, _newTokenPrice); // Emit event
    }
 
 
    // Update the minimum buy value in USDT
    function setMinThreshold(uint256 _minThresholdLimit) external onlyOwner {
        require(_minThresholdLimit > 0, "Threshold must be greater than 0");
        minThresholdLimit = _minThresholdLimit;
        emit minThresholdUpdated(_minThresholdLimit); // Emit event
    }
 
    function updateAggregatorPairAddress(address _newPairAddress)
        external
        onlyOwner
    {
        require(_newPairAddress != address(0), "Invalid Pair address");
        priceFeed = AggregatorV3Interface(_newPairAddress); // POL/USDT Pair Price Feed Address
        emit AggregatorPairUpdated(_newPairAddress);
    }
 
    function getContractBal(address _tokenAddress)
        public
        view
        returns (uint256)
    {
        require(_tokenAddress != address(0), "Invalid token address");
        return IERC20(_tokenAddress).balanceOf(address(this));
    }
 
    receive() external payable {}
}
 
