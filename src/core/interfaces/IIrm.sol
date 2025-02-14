// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Id} from "./IArtha.sol";

interface Iirm {
    function getBorrowRate(Id) external returns (uint256);
}
