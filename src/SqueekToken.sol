// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title squeek (SQK)
/// @notice Fixed supply ERC-20. The constructor mints every token to its caller.
/// @dev No owner, additional minting, burning, fees, or upgrade mechanism.
contract SqueekToken is ERC20 {
    /// @notice One billion SQK expressed in base units (18 decimals).
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("squeek", "SQK") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
