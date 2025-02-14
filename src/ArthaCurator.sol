// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IArtha, Id, PoolParams} from "../src/core/interfaces/IArtha.sol";
import {Artha} from "../src/core/Artha.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ArthaCurator is Ownable, ERC4626 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    Artha public immutable artha;
    IERC20 public immutable depositToken;

    uint256 constant ALLOCATION_SCALED = 1e18;
    bytes32[] public poolList;

    mapping(bytes32 => uint256) public poolAlocations;
    mapping(address => bool) public curators;

    address public feeRecipient;
    uint256 public feePercentage; // Fee percentage in basis points (e.g., 100 = 1%)

    event CuratorUpdated(address indexed curator, bool isCurator);
    event AllocationSetup(bytes32 indexed poolId, uint256 allocation);
    event FeeRecipientUpdated(address indexed newRecipient);
    event FeePercentageUpdated(uint256 newFeePercentage);

    error ZeroAddress();
    error InvalidLength(uint256 poolLength, uint256 allocationLength);
    error AllocationToHigh();
    error InvalidAmount();
    error InsufficientTokenBalance(uint256 available, uint256 required);
    error InvalidShares(uint256 provided);
    error InsufficientShares(uint256 available, uint256 required);
    error NotImplemented();

    constructor(address _artha, address _depositToken)
        ERC4626(IERC20(_depositToken))
        Ownable(msg.sender)
        ERC20("Artha Pool Token", "APT")
    {
        if (_artha == address(0)) revert ZeroAddress();
        if (address(_depositToken) == address(0)) revert ZeroAddress();

        artha = Artha(_artha);
        depositToken = IERC20(address(_depositToken));
    }

    function setAllocation(bytes32[] memory poolIds, uint256[] memory allocations) external onlyOwner {
        if (poolIds.length > allocations.length) revert InvalidLength(poolIds.length, allocations.length);

        delete poolList;
        uint256 totalAllocation = 0;

        for (uint256 i = 0; i < poolIds.length; i++) {
            poolAlocations[poolIds[i]] = allocations[i];
            if (allocations[i] > ALLOCATION_SCALED) revert AllocationToHigh();
            poolList.push(poolIds[i]);

            totalAllocation += allocations[i];
        }

        if (totalAllocation > ALLOCATION_SCALED) revert AllocationToHigh();

        emit AllocationSetup(poolIds[0], allocations[0]);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 10000, "Fee percentage too high");
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(_feePercentage);
    }

    function _accrueFee(uint256 shares) internal returns (uint256) {
        if (feePercentage == 0 || feeRecipient == address(0)) {
            return shares;
        }

        uint256 feeShares = (shares * feePercentage) / 10000;
        _mint(feeRecipient, feeShares);
        return shares - feeShares;
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        if (assets <= 0) revert InvalidAmount();
        if (depositToken.balanceOf(msg.sender) < assets) {
            revert InsufficientTokenBalance(depositToken.balanceOf(msg.sender), assets);
        }

        depositToken.safeTransferFrom(msg.sender, address(this), assets);
        depositToken.approve(address(artha), assets);

        for (uint256 i = 0; i < poolList.length; i++) {
            uint256 depositAmount = (assets * poolAlocations[poolList[i]]) / ALLOCATION_SCALED;
            artha.supply(Id.wrap(poolList[i]), depositAmount, address(this));
        }

        uint256 shares = previewDeposit(assets);
        shares = _accrueFee(shares);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256 assets) {
        if (shares == 0) revert InvalidShares(shares);
        if (balanceOf(owner) < shares) revert InsufficientShares(balanceOf(owner), shares);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        uint256 beforeBalance = depositToken.balanceOf(address(this));

        for (uint256 i = 0; i < poolList.length; i++) {
            uint256 poolShare = artha.supplies(Id.wrap(poolList[i]), address(this));
            uint256 withdrawShare = (shares * poolShare) / totalSupply();
            artha.withdraw(Id.wrap(poolList[i]), withdrawShare, address(this), address(this));
        }

        uint256 afterBalance = depositToken.balanceOf(address(this));
        assets = afterBalance - beforeBalance;

        if (assets == 0) revert InvalidAmount();
        depositToken.safeTransfer(receiver, assets);
        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }

    modifier onlyCurator() {
        require(curators[msg.sender], "Not authorized curator");
        _;
    }

    function totalAssets() public view virtual override returns (uint256) {
        uint256 totalAsset = 0;
        for (uint256 i = 0; i < poolList.length; i++) {
            (,,,,,, uint256 totalSupplyAsset, uint256 totalSupplyShare,,,) = artha.pools(Id.wrap(poolList[i]));
            uint256 totalSupplys = artha.supplies(Id.wrap(poolList[i]), address(this));
            totalAsset += totalSupplyAsset * totalSupplys / totalSupplyShare;
        }
        return totalAsset;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return totalSupply() == 0 ? assets : (assets * totalSupply()) / totalAssets();
    }

    function withdraw(uint256, address, address) public virtual override returns (uint256) {
        revert NotImplemented();
    }

    function maxWithdraw(address) public view virtual override returns (uint256) {
        revert NotImplemented();
    }

    function maxMint(address) public view virtual override returns (uint256) {
        revert NotImplemented();
    }

    function previewWithdraw(uint256) public view virtual override returns (uint256) {
        revert NotImplemented();
    }

    function previewMint(uint256) public view virtual override returns (uint256) {
        revert NotImplemented();
    }
}
