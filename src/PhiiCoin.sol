// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title PhiiCoin - optimized ERC20
contract PhiiCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("Phii Coin", "PHII") {
        _mint(msg.sender, initialSupply);
    }
}