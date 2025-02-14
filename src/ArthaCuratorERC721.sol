// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IArtha, Id, PoolParams} from "../src/core/interfaces/IArtha.sol";
import {Artha} from "../src/core/Artha.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ArthaCuratorERC721 is Ownable, ERC20 {
    using SafeERC20 for IERC20;

    Artha public immutable artha;
    IERC20 public immutable depositToken;

    uint256 constant ALLOCATION_SCALED = 1e18;
    bytes32[] public poolList;

    mapping(bytes32 => uint256) public poolAlocations;
    mapping(address => bool) public curators;

    event CuratorUpdated(address indexed curator, bool isCurator);
    event DepositedToArtha(address indexed user, uint256 amount, uint256 mintedTokens);
    event AllocationSetup(bytes32 indexed poolId, uint256 allocation);
    event WithdrawSuccessfull(uint256 shares, address indexed user, uint256 amount);

    error ZeroAddress();
    error InvalidLength(uint256 poolLength, uint256 allocationLength);
    error AllocationToHigh();
    error InvalidAmount();
    error InsufficientTokenBalance(uint256 available, uint256 required);
    error InvalidShares(uint256 provided);
    error InsufficientShares(uint256 available, uint256 required);

    constructor(address _artha, address _depositToken) Ownable(msg.sender) ERC20("Artha Pool Token", "APT") {
        if (_artha == address(0)) revert ZeroAddress();
        if (_depositToken == address(0)) revert ZeroAddress();

        artha = Artha(_artha);
        depositToken = IERC20(_depositToken);
    }

    function setAllocation(bytes32[] memory poolIds, uint256[] memory allocations) external onlyOwner {
        if (poolIds.length > allocations.length) revert InvalidLength(poolIds.length, allocations.length);

        if (poolList.length > 0) {
            delete poolList;
        }

        for (uint256 i = 0; i < poolIds.length; i++) {
            poolAlocations[poolIds[i]] = allocations[i];
            if (allocations[i] > ALLOCATION_SCALED) revert AllocationToHigh();
            poolList.push(poolIds[i]);
        }

        emit AllocationSetup(poolIds[0], allocations[0]);
    }

    function setCurator(address curator, bool isCurator) external onlyOwner {
        if (curator == address(0)) revert ZeroAddress();

        curators[curator] = isCurator;
        emit CuratorUpdated(curator, isCurator);
    }

    function depositToArtha(uint256 amount) external {
        if (amount <= 0) revert InvalidAmount();
        if (depositToken.balanceOf(msg.sender) < amount) {
            revert InsufficientTokenBalance(depositToken.balanceOf(msg.sender), amount);
        }

        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        depositToken.approve(address(artha), amount);

        for (uint256 i = 0; i < poolList.length; i++) {
            uint256 depositAmount = (amount * poolAlocations[poolList[i]]) / ALLOCATION_SCALED;
            artha.supply(Id.wrap(poolList[i]), depositAmount, address(this));
        }
        uint256 shares = 0;

        if (totalSupply() == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply()) / totalAsset();
        }
        _mint(msg.sender, shares);

        emit DepositedToArtha(msg.sender, amount, shares);
    }

    function totalAsset() public view returns (uint256) {
        uint256 totalAssets = 0;
        for (uint256 i = 0; i < poolList.length; i++) {
            (,,,,,, uint256 totalSupplyAsset, uint256 totalSupplyShare,,,) = artha.pools(Id.wrap(poolList[i]));
            uint256 totalSupplys = artha.supplies(Id.wrap(poolList[i]), address(this));
            totalAssets += totalSupplyAsset * totalSupplys / totalSupplyShare;
        }
        return totalAssets;
    }

    function withdrawFromArtha(uint256 shares) external {
        if (shares < 0) revert InvalidShares(shares);
        if (balanceOf(msg.sender) < shares) revert InsufficientShares(balanceOf(msg.sender), shares);

        uint256 beforeBalance = depositToken.balanceOf(address(this));

        for (uint256 i = 0; i < poolList.length; i++) {
            uint256 poolShare = artha.supplies(Id.wrap(poolList[i]), address(this));
            uint256 withdrawShare = (shares * poolShare) / totalSupply();
            artha.withdraw(Id.wrap(poolList[i]), withdrawShare, address(this), address(this));
        }

        uint256 afterBalance = depositToken.balanceOf(address(this));
        uint256 withdrawAmount = afterBalance - beforeBalance;
        depositToken.safeTransfer(msg.sender, withdrawAmount);
        _burn(msg.sender, shares);

        emit WithdrawSuccessfull(shares, msg.sender, withdrawAmount);
    }

    modifier onlyCurator() {
        require(curators[msg.sender], "Not authorized curator");
        _;
    }
}
