// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract functionIntro {
    uint age = 20;
    function add(uint x, uint y) public pure returns (uint) {
        return x + y;
    }
    function changeAge() public {
        age += 1;
    }
    function getage() public view returns (uint) {
        return age;
    }
    function fun() internal {
        //code;
    }
}
