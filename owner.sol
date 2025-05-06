// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract OwnerContract {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Invalid Owner");
        _;
    }

    function setOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invailed Address");
        owner = _newOwner;
    }

    function OwnerCanAccess() public onlyOwner {
        //code
    }

    function PublicCanAccess() public {
        //code
    }
}
