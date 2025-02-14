// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Id} from "../interfaces/IArtha.sol";
import {Iirm} from "../interfaces/IIrm.sol";

contract MockIrm is Iirm {
    function getBorrowRate(Id) external pure returns (uint256) {
        return 5e15; // 5%/year
    }
}
