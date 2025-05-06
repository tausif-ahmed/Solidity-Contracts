// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract stateVariable {
    uint public salary;
    constructor() {
        salary = 10;
    }
    function setsalary() public {
        salary = 2000;
    }
}
