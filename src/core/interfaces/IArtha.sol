// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

type Id is bytes32;

struct PoolParams {
    address collateralToken;
    address loanToken;
    address oracle;
    address irm;
    uint256 ltv;
    uint256 lth;
}

struct Pool {
    address collateralToken;
    address loanToken;
    address oracle;
    address irm;
    uint256 ltv;
    uint256 lth;
    uint256 totalSupplyAssets;
    uint256 totalSupplyShares;
    uint256 totalBorrowAssets;
    uint256 totalBorrowShares;
    uint256 lastAccrued;
}

struct Position {
    uint256 borrowShares;
    address owner;
    address bidder;
    uint256 bid;
    uint256 endTime;
}

interface IArtha {
    function pools(Id id)
        external
        view
        returns (
            address collateralToken,
            address loanToken,
            address oracle,
            address irm,
            uint256 ltv,
            uint256 lth,
            uint256 totalSupplyAssets,
            uint256 totalSupplyShares,
            uint256 totalBorrowAssets,
            uint256 totalBorrowShares,
            uint256 lastAccrued
        );
}
