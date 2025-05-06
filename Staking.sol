// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
 
contract FinityStaking is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 immutable token;
 
    uint256 public totalStakedAmount;
    uint256 public totalInterestAmount;
 
    // APY constants (in basis points, where 10000 = 100%)
    uint256 public PLAN_1_APY = 897; // 8.97% annual
    uint256 public PLAN_2_APY = 1435; // 14.35% annual
    uint256 public PLAN_3_APY = 2152; // 21.52% annual
    uint256 public PLAN_4_APY = 2869; // 28.69% annual
 
    uint256 public  PLAN_1_DAYS = 90 days;
    uint256 public  PLAN_2_DAYS = 365 days;
    uint256 public  PLAN_3_DAYS = 730 days;
    uint256 public  PLAN_4_DAYS = 1460 days;
 
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 apy;
        bool withdrawn;
    }
 
    mapping(address => Stake[]) public stakes;
    address[] public stakeHolders;
 
    event Staked(address indexed user, uint256 amount, uint256 duration, uint256 apy);
    event Unstaked(address indexed user, uint256 amount, uint256 interest);
    event AdminWithdraw(address indexed admin, uint256 amount);
    event AdminDeposit(address indexed admin, uint256 amount);
    event APYUpdated(uint256 PLAN_1_APY, uint256 PLAN_2_APY, uint256 PLAN_3_APY, uint256 PLAN_4_APY);
    event PlanDaysUpdated(uint256 PLAN_1_DAYS, uint256 PLAN_2_DAYS, uint256 PLAN_3_DAYS, uint256 PLAN_4_DAYS);
 
    constructor(address _multiSigWallet,address _finitytoken) Ownable(_multiSigWallet) {
        token = IERC20(_finitytoken); // finity contract address
    }
 
    // Stake function
    function stake(uint256 amount, uint256 plan) external nonReentrant {
        require(amount > 0, "Invalid stake amount");
        
        (uint256 apy, uint256 duration) = getPlanDetails(plan);
        
        uint256 interest = calculateInterest(amount, apy, duration);
        uint256 totalStakingAmount = totalStakedAmount + totalInterestAmount+ interest;
        require(token.balanceOf(address(this)) >= totalStakingAmount, "Insufficient contract balance");
 
        token.safeTransferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].push(
            Stake({
                amount: amount,
                startTime: block.timestamp,
                duration: duration,
                apy: apy,
                withdrawn: false
            })
        );
 
        if (stakes[msg.sender].length == 1) {
            stakeHolders.push(msg.sender);
        }
 
        totalStakedAmount += amount;
        totalInterestAmount+=interest;
 
        emit Staked(msg.sender, amount, duration, apy);
    }
 
    function getPlanDetails(uint256 plan) internal view returns (uint256, uint256) {
        if (plan == 1) {
            return (PLAN_1_APY, PLAN_1_DAYS);
        } else if (plan == 2) {
            return (PLAN_2_APY, PLAN_2_DAYS);
        } else if (plan == 3) {
            return (PLAN_3_APY, PLAN_3_DAYS);
        } else if (plan == 4) {
            return (PLAN_4_APY, PLAN_4_DAYS);
        } else {
            revert("Invalid staking plan");
        }
    }
 
    function calculateInterest(
        uint256 amount,
        uint256 apy,
        uint256 duration
    ) private pure returns (uint256) {
        uint256 interest = (amount * apy * duration) / (365 days * 10000);
        return interest;
    }
 
    function unstake(uint256 stakeIndex) external nonReentrant {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        
        Stake memory userStake = stakes[msg.sender][stakeIndex];
        require(!userStake.withdrawn, "Stake already withdrawn");
        require(block.timestamp >= userStake.startTime + userStake.duration, "Staking period incomplete");
 
        uint256 interest = calculateInterest(userStake.amount, userStake.apy, userStake.duration);
        uint256 totalAmount = userStake.amount + interest;
 
        userStake.withdrawn = true;
 
        token.safeTransfer(msg.sender, totalAmount);
 
        totalStakedAmount -= userStake.amount;
        totalInterestAmount-=interest;
 
        emit Unstaked(msg.sender, userStake.amount, interest);
    }
 
    function withdrawExcessTokens(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Invalid withdrawal amount");
        
        uint256 requiredBalance = totalStakedAmount + totalInterestAmount;
        uint256 availableBalance = token.balanceOf(address(this)) - requiredBalance;
 
        require(amount <= availableBalance, "Insufficient tokens");
 
        token.safeTransfer(msg.sender, amount);
 
        emit AdminWithdraw(msg.sender, amount);
    }
 
   function adminDeposit(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Invalid deposit amount");
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit AdminDeposit(msg.sender, amount);
    }
 
    function updateAPY(uint256 _plan1APY, uint256 _plan2APY, uint256 _plan3APY, uint256 _plan4APY) external onlyOwner {
        require(_plan1APY > 0 && _plan2APY > 0 && _plan3APY > 0 && _plan4APY > 0, "APY must be positive");
        require(_plan1APY <= 10000 && _plan2APY <= 10000 && _plan3APY <= 10000 && _plan4APY <= 10000, "APY too high");
 
        // Update APY values
        PLAN_1_APY = _plan1APY;
        PLAN_2_APY = _plan2APY;
        PLAN_3_APY = _plan3APY;
        PLAN_4_APY = _plan4APY;
 
        emit APYUpdated(_plan1APY, _plan2APY, _plan3APY, _plan4APY);
    }
 
    function updatePlanDuration(uint256 _plan1Days, uint256 _plan2Days, uint256 _plan3Days, uint256 _plan4Days) external onlyOwner {
        require(_plan1Days > 0 && _plan1Days > 0 && _plan1Days > 0 && _plan1Days > 0, "APY must be positive");
 
        // Update Days values for Plans
        PLAN_1_DAYS = _plan1Days;
        PLAN_2_DAYS = _plan2Days;
        PLAN_3_DAYS = _plan3Days;
        PLAN_4_DAYS = _plan4Days;
 
        emit PlanDaysUpdated(_plan1Days, _plan2Days, _plan3Days, _plan4Days);
    }
 
    function getUserStakes(address user) external view returns (Stake[] memory) {
        require(user != address(0), "Invalid user address");
        return stakes[user];
    }
 
    function getContractBal(address _tokenAddress)
        public
        view
        returns (uint256)
    {
        require(_tokenAddress != address(0), "Invalid token address");
        return IERC20(_tokenAddress).balanceOf(address(this));
    }
}
