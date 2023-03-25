// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import { Test } from "forge-std/Test.sol";
import { FuzzHelpers } from "./FuzzHelpers.sol";
import {
    TestCalldataHashContractOfferer
} from "../../../../contracts/test/TestCalldataHashContractOfferer.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    OrderParametersLib
} from "../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

/**
 * @dev Check functions are the post-execution assertions we want to validate.
 *      Checks should be public functions that accept a FuzzTestContext as their
 *      only argument. Checks have access to the post-execution FuzzTestContext
 *      and can use it to make test assertions. The check phase happens last,
 *      immediately after execution.
 */
abstract contract FuzzChecks is Test {
    using OrderParametersLib for OrderParameters;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder[];

    address payable testZone;
    address payable contractOfferer;

    /**
     * @dev Check that the returned `fulfilled` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderFulfilled(FuzzTestContext memory context) public {
        assertEq(context.returnValues.fulfilled, true);
    }

    /**
     * @dev Check that the returned `validated` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderValidated(FuzzTestContext memory context) public {
        assertEq(context.returnValues.validated, true);
    }

    /**
     * @dev Check that the returned `cancelled` values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_orderCancelled(FuzzTestContext memory context) public {
        assertEq(context.returnValues.cancelled, true);
    }

    /**
     * @dev Check that the returned `availableOrders` array length was the
     *      expected length. and that all values were `true`.
     *
     * @param context A Fuzz test context.
     */
    function check_allOrdersFilled(FuzzTestContext memory context) public {
        assertEq(
            context.returnValues.availableOrders.length,
            context.initialOrders.length
        );
        for (uint256 i; i < context.returnValues.availableOrders.length; i++) {
            assertTrue(context.returnValues.availableOrders[i]);
        }
    }

    /**
     * @dev Check that the zone is getting the right calldata.
     *
     * @param context A Fuzz test context.
     */
    function check_validateOrderExpectedDataHash(
        FuzzTestContext memory context
    ) public {
        for (uint256 i; i < context.orders.length; i++) {
            if (context.orders[i].parameters.zone != address(0)) {
                testZone = payable(context.orders[i].parameters.zone);

                AdvancedOrder memory order = context.orders[i];

                bytes32 expectedCalldataHash = context.expectedZoneCalldataHash[
                    i
                ];

                uint256 counter = context.seaport.getCounter(
                    order.parameters.offerer
                );

                OrderComponents memory orderComponents = order
                    .parameters
                    .toOrderComponents(counter);

                bytes32 orderHash = context.seaport.getOrderHash(
                    orderComponents
                );

                bytes32 actualCalldataHash = HashValidationZoneOfferer(testZone)
                    .orderHashToValidateOrderDataHash(orderHash);

                assertEq(actualCalldataHash, expectedCalldataHash);
            }
        }
    }

    function check_contractOrderExpectedDataHashes(
        FuzzTestContext memory context
    ) public {
        bytes32[] memory orderHashes = context.orders.getOrderHashes(
            address(context.seaport)
        );
        bytes32[2][] memory expectedCalldataHashes = context
            .expectedContractOrderCalldataHashes;
        for (uint256 i; i < context.orders.length; i++) {
            AdvancedOrder memory order = context.orders[i];

            bytes32 orderHash = orderHashes[i];

            bytes32 expectedGenerateOrderCalldataHash = expectedCalldataHashes[
                i
            ][0];

            bytes32 expectedRatifyOrderCalldataHash = expectedCalldataHashes[i][
                1
            ];

            bytes32 actualGenerateOrderCalldataHash;
            bytes32 actualRatifyOrderCalldataHash;

            if (order.parameters.orderType == OrderType.CONTRACT) {
                contractOfferer = payable(order.parameters.offerer);

                // Decrease contractOffererNonce in the orderHash by 1 since it
                // has increased by 1 post-execution.
                bytes32 generateOrderOrderHash;
                bytes32 mask = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0;

                assembly {
                    generateOrderOrderHash := and(orderHash, mask)
                }

                actualGenerateOrderCalldataHash = TestCalldataHashContractOfferer(
                    contractOfferer
                ).orderHashToGenerateOrderDataHash(generateOrderOrderHash);

                actualRatifyOrderCalldataHash = TestCalldataHashContractOfferer(
                    contractOfferer
                ).orderHashToRatifyOrderDataHash(orderHash);
            } else {
                actualGenerateOrderCalldataHash = bytes32(0);
                actualRatifyOrderCalldataHash = bytes32(0);
            }

            assertEq(
                expectedGenerateOrderCalldataHash,
                actualGenerateOrderCalldataHash
            );
            assertEq(
                expectedRatifyOrderCalldataHash,
                actualRatifyOrderCalldataHash
            );
        }
    }

    /**
     * @dev Check that the returned `executions` and `expectedExecutions` match.
     *
     * @param context A Fuzz test context.
     */
    function check_executions(FuzzTestContext memory context) public {
        // TODO: fulfillAvailable cases return an extra expected execution
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return;
        }
        assertEq(
            context.returnValues.executions.length,
            context.expectedExplicitExecutions.length,
            "check_executions: expectedExplicitExecutions.length != returnValues.executions.length"
        );
        // TODO: hash and compare arrays. order seems not to be guaranteed
        //assertEq(
        //    keccak256(abi.encode(context.returnValues.executions)),
        //    keccak256(abi.encode(context.expectedExplicitExecutions.length)),
        //    "check_executions: expectedExplicitExecutions != returnValues.executions"
        //);
    }
}

// state variable accessible in test or pass into FuzzTestContext
