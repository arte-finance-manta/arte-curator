// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626, ERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockCurator is ERC4626 {
    constructor(string memory _name, string memory _symbol, address _asset)
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol)
    {}
}
