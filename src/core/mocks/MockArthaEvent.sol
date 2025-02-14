// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IArtha, Id, Pool, Position, PoolParams} from "../interfaces/IArtha.sol";

abstract contract MockArthaEvent is IArtha {
    event PoolCreated(Id id, PoolParams poolParams);
    event InterestRateModelChanged(address irm, bool enabled);
    event LTVChanged(uint256 ltv, bool enabled);
    event SupplyCollateral(Id id, uint256 tokenId, address sender, address onBehalOf);
    event WithdrawCollateral(Id id, uint256 tokenId, address sender, address onBehalfOf, address receiver);
    event Supply(Id id, address sender, address onBehalfOf, uint256 amount, uint256 shares);
    event Withdraw(Id id, address sender, address onBehalfOf, address receiver, uint256 amount, uint256 shares);
    event Borrow(
        Id id, uint256 tokenId, address sender, address onBehalfOf, address receiver, uint256 amount, uint256 shares
    );
    event Repay(Id id, uint256 tokenId, address sender, address onBehalfOf, uint256 amount, uint256 shares);
    event Bid(Id id, uint256 tokenId, address bidder, uint256 amount);
    event AuctionSettled(Id id, uint256 tokenId, address bidder, uint256 amount);

    function setInterestRateModel(address irm, bool enabled) external {
        emit InterestRateModelChanged(irm, enabled);
    }

    function setLTV(uint256 ltv, bool enabled) external {
        emit LTVChanged(ltv, enabled);
    }

    function createPool(PoolParams memory poolParams) external returns (Id) {
        Id id = computeId(poolParams);

        emit PoolCreated(id, poolParams);

        return id;
    }

    function computeId(PoolParams memory poolParams) public pure returns (Id id) {
        assembly ("memory-safe") {
            id := keccak256(poolParams, 192)
        }
    }

    function supply(Id id, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        emit Supply(id, msg.sender, onBehalfOf, amount, amount - 1);

        return (amount, amount - 1);
    }

    function withdraw(Id id, uint256 shares, address onBehalfOf, address receiver)
        external
        returns (uint256, uint256)
    {
        emit Withdraw(id, msg.sender, onBehalfOf, receiver, shares - 1, shares);

        return (shares - 1, shares);
    }

    function borrow(Id id, uint256 tokenId, uint256 amount, address onBehalfOf, address receiver)
        external
        returns (uint256, uint256)
    {
        emit Borrow(id, tokenId, msg.sender, onBehalfOf, receiver, amount, amount - 1);

        return (amount, amount - 1);
    }

    function repay(Id id, uint256 tokenId, uint256 shares, address onBehalfOf) external returns (uint256, uint256) {
        emit Repay(id, tokenId, msg.sender, onBehalfOf, shares - 1, shares);

        return (shares - 1, shares);
    }

    function supplyCollateral(Id id, uint256 tokenId, address onBehalfOf) external {
        emit SupplyCollateral(id, tokenId, msg.sender, onBehalfOf);
    }

    function withdrawRoyalty(Id id, uint256 tokenId, address onBehalfOf, address receiver) external {}

    function withdrawCollateral(Id id, uint256 tokenId, address onBehalfOf, address receiver) external {
        emit WithdrawCollateral(id, tokenId, msg.sender, onBehalfOf, receiver);
    }

    // =============================================================
    //                         Auction
    // =============================================================

    function bid(Id id, uint256 tokenId, uint256 amount) external {
        emit Bid(id, tokenId, msg.sender, amount);
    }

    function settleAuction(Id id, uint256 tokenId) external {
        emit AuctionSettled(id, tokenId, msg.sender, 10e6);
    }
}
