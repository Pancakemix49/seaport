// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderHelperRequestValidatorLib } from "./OrderHelperLib.sol";

import {
    CriteriaConstraint,
    OrderHelperContext,
    OrderHelperResponse
} from "./SeaportOrderHelperTypes.sol";

import { HelperInterface } from "./HelperInterface.sol";

contract RequestValidator is HelperInterface {
    using OrderHelperRequestValidatorLib for OrderHelperContext;

    function prepare(
        OrderHelperContext memory context
    ) public view returns (OrderHelperContext memory) {
        return context.validate();
    }
}
