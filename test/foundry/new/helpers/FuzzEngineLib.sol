// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import { Family, FuzzHelpers, Structure } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

/**
 * @notice Stateless helpers for FuzzEngine.
 */
library FuzzEngineLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    /**
     * @dev Select an available "action," i.e. "which Seaport function to call,"
     *      based on the orders in a given FuzzTestContext. Selects a random action
     *      using the context's fuzzParams.seed when multiple actions are
     *      available for the given order config.
     *
     * @param context A Fuzz test context.
     * @return bytes4 selector of a SeaportInterface function.
     */
    function action(FuzzTestContext memory context) internal returns (bytes4) {
        if (context._action != bytes4(0)) return context._action;
        bytes4[] memory _actions = actions(context);
        return (context._action = _actions[
            context.fuzzParams.seed % _actions.length
        ]);
    }

    function actionName(
        FuzzTestContext memory context
    ) internal returns (string memory) {
        bytes4 selector = action(context);
        if (selector == 0xe7acab24) return "fulfillAdvancedOrder";
        if (selector == 0x87201b41) return "fulfillAvailableAdvancedOrders";
        if (selector == 0xed98a574) return "fulfillAvailableOrders";
        if (selector == 0xfb0f3ee1) return "fulfillBasicOrder";
        if (selector == 0x00000000) return "fulfillBasicOrder_efficient_6GL6yc";
        if (selector == 0xb3a34c4c) return "fulfillOrder";
        if (selector == 0xf2d12b12) return "matchAdvancedOrders";
        if (selector == 0xa8174404) return "matchOrders";

        revert("Unknown selector");
    }

    /**
     * @dev Get an array of all possible "actions," i.e. "which Seaport
     *      functions can we call," based on the orders in a given FuzzTestContext.
     *
     * @param context A Fuzz test context.
     * @return bytes4[] of SeaportInterface function selectors.
     */
    function actions(
        FuzzTestContext memory context
    ) internal returns (bytes4[] memory) {
        Family family = context.orders.getFamily();

        bool invalidNativeOfferItemsLocated = (
            hasInvalidNativeOfferItems(context)
        );

        Structure structure = context.orders.getStructure(
            address(context.seaport)
        );

        if (family == Family.SINGLE && !invalidNativeOfferItemsLocated) {
            if (structure == Structure.BASIC) {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillBasicOrder.selector;
                selectors[3] = context
                    .seaport
                    .fulfillBasicOrder_efficient_6GL6yc
                    .selector;
                return selectors;
            }

            if (structure == Structure.STANDARD) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                return selectors;
            }

            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context.seaport.fulfillAdvancedOrder.selector;
                return selectors;
            }
        }

        (, , MatchComponent[] memory remainders) = context
            .testHelpers
            .getMatchedFulfillments(context.orders, context.criteriaResolvers);

        if (remainders.length != 0 && invalidNativeOfferItemsLocated) {
            revert("FuzzEngineLib: cannot fulfill provided combined order");
        }

        if (remainders.length != 0) {
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillAvailableOrders.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                //selectors[2] = context.seaport.cancel.selector;
                //selectors[3] = context.seaport.validate.selector;
                return selectors;
            }
        } else if (invalidNativeOfferItemsLocated) {
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = context.seaport.matchAdvancedOrders.selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.matchOrders.selector;
                selectors[1] = context.seaport.matchAdvancedOrders.selector;
                return selectors;
            }
        } else {
            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                selectors[1] = context.seaport.matchAdvancedOrders.selector;
                return selectors;
            } else {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillAvailableOrders.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                selectors[2] = context.seaport.matchOrders.selector;
                selectors[3] = context.seaport.matchAdvancedOrders.selector;
                //selectors[4] = context.seaport.cancel.selector;
                //selectors[5] = context.seaport.validate.selector;
                return selectors;
            }
        }
    }

    function hasInvalidNativeOfferItems(
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
            if (orderParams.orderType == OrderType.CONTRACT) {
                continue;
            }

            for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                OfferItem memory item = orderParams.offer[j];

                if (item.itemType == ItemType.NATIVE) {
                    return true;
                }
            }
        }

        return false;
    }

    function getNativeTokensToSupply(
        FuzzTestContext memory context
    ) internal view returns (uint256) {
        uint256 value = 0;

        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
            for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                OfferItem memory item = orderParams.offer[j];

                if (item.itemType == ItemType.NATIVE) {
                    if (item.startAmount != item.endAmount) {
                        value += _locateCurrentAmount(
                            item.startAmount,
                            item.endAmount,
                            orderParams.startTime,
                            orderParams.endTime,
                            true
                        );
                    } else {
                        value += item.startAmount;
                    }
                }
            }

            for (uint256 j = 0; j < orderParams.consideration.length; ++j) {
                ConsiderationItem memory item = orderParams.consideration[j];

                if (item.itemType == ItemType.NATIVE) {
                    if (item.startAmount != item.endAmount) {
                        value += _locateCurrentAmount(
                            item.startAmount,
                            item.endAmount,
                            orderParams.startTime,
                            orderParams.endTime,
                            false
                        );
                    } else {
                        value += item.startAmount;
                    }
                }
            }
        }

        return value;
    }

    function _locateCurrentAmount(
        uint256 startAmount,
        uint256 endAmount,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) internal view returns (uint256 amount) {
        // Only modify end amount if it doesn't already equal start amount.
        if (startAmount != endAmount) {
            // Declare variables to derive in the subsequent unchecked scope.
            uint256 duration;
            uint256 elapsed;
            uint256 remaining;

            // Skip underflow checks as startTime <= block.timestamp < endTime.
            unchecked {
                // Derive the duration for the order and place it on the stack.
                duration = endTime - startTime;

                // Derive time elapsed since the order started & place on stack.
                elapsed = block.timestamp - startTime;

                // Derive time remaining until order expires and place on stack.
                remaining = duration - elapsed;
            }

            // Aggregate new amounts weighted by time with rounding factor.
            uint256 totalBeforeDivision = ((startAmount * remaining) +
                (endAmount * elapsed));

            // Use assembly to combine operations and skip divide-by-zero check.
            assembly {
                // Multiply by iszero(iszero(totalBeforeDivision)) to ensure
                // amount is set to zero if totalBeforeDivision is zero,
                // as intermediate overflow can occur if it is zero.
                amount := mul(
                    iszero(iszero(totalBeforeDivision)),
                    // Subtract 1 from the numerator and add 1 to the result if
                    // roundUp is true to get the proper rounding direction.
                    // Division is performed with no zero check as duration
                    // cannot be zero as long as startTime < endTime.
                    add(
                        div(sub(totalBeforeDivision, roundUp), duration),
                        roundUp
                    )
                )
            }

            // Return the current amount.
            return amount;
        }

        // Return the original amount as startAmount == endAmount.
        return endAmount;
    }
}
