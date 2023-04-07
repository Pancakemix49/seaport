// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

import {
    Family,
    FuzzHelpers,
    Structure,
    _locateCurrentAmount
} from "./FuzzHelpers.sol";

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

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.orders.getStructure(
            address(context.seaport)
        );

        bool hasUnavailable = context.maximumFulfilled < context.orders.length;
        for (uint256 i = 0; i < context.expectedAvailableOrders.length; ++i) {
            if (!context.expectedAvailableOrders[i]) {
                hasUnavailable = true;
                break;
            }
        }

        if (hasUnavailable) {
            if (invalidOfferItemsLocated) {
                revert(
                    "FuzzEngineLib: invalid native token + unavailable combination"
                );
            }

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
                return selectors;
            }
        }

        if (family == Family.SINGLE && !invalidOfferItemsLocated) {
            if (structure == Structure.BASIC) {
                bytes4[] memory selectors = new bytes4[](6);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillBasicOrder.selector;
                selectors[3] = context
                    .seaport
                    .fulfillBasicOrder_efficient_6GL6yc
                    .selector;
                selectors[4] = context.seaport.fulfillAvailableOrders.selector;
                selectors[5] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }

            if (structure == Structure.STANDARD) {
                bytes4[] memory selectors = new bytes4[](4);
                selectors[0] = context.seaport.fulfillOrder.selector;
                selectors[1] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[2] = context.seaport.fulfillAvailableOrders.selector;
                selectors[3] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }

            if (structure == Structure.ADVANCED) {
                bytes4[] memory selectors = new bytes4[](2);
                selectors[0] = context.seaport.fulfillAdvancedOrder.selector;
                selectors[1] = context
                    .seaport
                    .fulfillAvailableAdvancedOrders
                    .selector;
                return selectors;
            }
        }

        (, , MatchComponent[] memory remainders) = context
            .testHelpers
            .getMatchedFulfillments(context.orders, context.criteriaResolvers);

        bool cannotMatch = (remainders.length != 0 || hasUnavailable);

        if (cannotMatch && invalidOfferItemsLocated) {
            revert("FuzzEngineLib: cannot fulfill provided combined order");
        }

        if (cannotMatch) {
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
        } else if (invalidOfferItemsLocated) {
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

    function mustUseMatch(
        FuzzTestContext memory context
    ) internal view returns (bool) {
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

        for (uint256 i = 0; i < context.orders.length; ++i) {
            OrderParameters memory orderParams = context.orders[i].parameters;
            for (uint256 j = 0; j < orderParams.offer.length; ++j) {
                OfferItem memory item = orderParams.offer[j];

                if (
                    item.itemType == ItemType.ERC721 ||
                    item.itemType == ItemType.ERC721_WITH_CRITERIA
                ) {
                    uint256 resolvedIdentifier = item.identifierOrCriteria;

                    if (item.itemType == ItemType.ERC721_WITH_CRITERIA) {
                        if (item.identifierOrCriteria == 0) {
                            bytes32 itemHash = keccak256(
                                abi.encodePacked(
                                    uint256(i),
                                    uint256(j),
                                    Side.OFFER
                                )
                            );
                            resolvedIdentifier = context
                                .testHelpers
                                .criteriaResolverHelper()
                                .wildcardIdentifierForGivenItemHash(itemHash);
                        } else {
                            resolvedIdentifier = context
                                .testHelpers
                                .criteriaResolverHelper()
                                .resolvableIdentifierForGivenCriteria(
                                    item.identifierOrCriteria
                                )
                                .resolvedIdentifier;
                        }
                    }

                    for (uint256 k = 0; k < context.orders.length; ++k) {
                        OrderParameters memory comparisonOrderParams = context
                            .orders[k]
                            .parameters;
                        for (
                            uint256 l = 0;
                            l < comparisonOrderParams.consideration.length;
                            ++l
                        ) {
                            ConsiderationItem
                                memory considerationItem = comparisonOrderParams
                                    .consideration[l];

                            if (
                                considerationItem.itemType == ItemType.ERC721 ||
                                considerationItem.itemType ==
                                ItemType.ERC721_WITH_CRITERIA
                            ) {
                                uint256 considerationResolvedIdentifier = considerationItem
                                        .identifierOrCriteria;

                                if (
                                    considerationItem.itemType ==
                                    ItemType.ERC721_WITH_CRITERIA
                                ) {
                                    if (
                                        considerationItem
                                            .identifierOrCriteria == 0
                                    ) {
                                        bytes32 itemHash = keccak256(
                                            abi.encodePacked(
                                                uint256(k),
                                                uint256(l),
                                                Side.CONSIDERATION
                                            )
                                        );
                                        considerationResolvedIdentifier = context
                                            .testHelpers
                                            .criteriaResolverHelper()
                                            .wildcardIdentifierForGivenItemHash(
                                                itemHash
                                            );
                                    } else {
                                        considerationResolvedIdentifier = context
                                            .testHelpers
                                            .criteriaResolverHelper()
                                            .resolvableIdentifierForGivenCriteria(
                                                considerationItem
                                                    .identifierOrCriteria
                                            )
                                            .resolvedIdentifier;
                                    }
                                }

                                if (
                                    resolvedIdentifier ==
                                    considerationResolvedIdentifier &&
                                    item.token == considerationItem.token
                                ) {
                                    return true;
                                }
                            }
                        }
                    }
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

                if (
                    item.itemType == ItemType.NATIVE &&
                    orderParams.isAvailable()
                ) {
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

            for (uint256 j = 0; j < orderParams.consideration.length; ++j) {
                ConsiderationItem memory item = orderParams.consideration[j];

                if (
                    item.itemType == ItemType.NATIVE &&
                    orderParams.isAvailable()
                ) {
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
        }

        return value;
    }
}
