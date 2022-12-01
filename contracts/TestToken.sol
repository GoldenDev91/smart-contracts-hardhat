//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TestToken") {
        _mint(msg.sender, 1_000_000 * 10**18);
    }

    function claim(address claimer, uint256 amount) public {
        _mint(claimer, amount);
    }
}
//0x929E9E7af59b6061f7CE94d7313393dBFee85BCe