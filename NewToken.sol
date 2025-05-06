// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
 
contract Navada is ERC20, ERC20Burnable, ERC20Permit, Ownable2Step {
    constructor(address _multiSigWallet)
        ERC20("Navada", "NAVADA")
        ERC20Permit("Navada")
        Ownable(_multiSigWallet)
    {
        require(_multiSigWallet != address(0), "Invalid address");
        uint256 totalSupply = 8 * 1e9 * 10**decimals(); //8 Billion Supply
        _mint(_multiSigWallet, totalSupply);
    }
}
