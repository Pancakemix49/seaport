// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    ZoneParameters,
    CriteriaResolver
} from "../../../lib/ConsiderationStructs.sol";

import { SeaportInterface } from "../../../interfaces/SeaportInterface.sol";

import { GettersAndDerivers } from "../../../lib/GettersAndDerivers.sol";

import { AdvancedOrderLib } from "./AdvancedOrderLib.sol";

import { ConsiderationItemLib } from "./ConsiderationItemLib.sol";

import { OfferItemLib } from "./OfferItemLib.sol";

import { ReceivedItemLib } from "./ReceivedItemLib.sol";

import { OrderParametersLib } from "./OrderParametersLib.sol";

import { StructCopier } from "./StructCopier.sol";

import { AmountDeriverHelper } from "./fulfillment/AmountDeriverHelper.sol";
import { OrderDetails } from "../fulfillments/lib/Structs.sol";

library ZoneParametersLib {
    using AdvancedOrderLib for AdvancedOrder;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    function getZoneParameters(
        AdvancedOrder memory advancedOrder,
        address fulfiller,
        uint256 counter,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal view returns (ZoneParameters memory zoneParameters) {
        SeaportInterface seaportInterface = SeaportInterface(seaport);
        // Get orderParameters from advancedOrder
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Get orderComponents from orderParameters
        OrderComponents memory orderComponents = OrderComponents({
            offerer: orderParameters.offerer,
            zone: orderParameters.zone,
            offer: orderParameters.offer,
            consideration: orderParameters.consideration,
            orderType: orderParameters.orderType,
            startTime: orderParameters.startTime,
            endTime: orderParameters.endTime,
            zoneHash: orderParameters.zoneHash,
            salt: orderParameters.salt,
            conduitKey: orderParameters.conduitKey,
            counter: counter
        });

        uint256 lengthWithTips = orderComponents.consideration.length;

        ConsiderationItem[] memory considerationSansTips = (
            orderComponents.consideration
        );

        uint256 lengthSansTips = (
            orderParameters.totalOriginalConsiderationItems
        );

        // set proper length of the considerationSansTips array.
        assembly {
            mstore(considerationSansTips, lengthSansTips)
        }

        // Get orderHash from orderComponents
        bytes32 orderHash = seaportInterface.getOrderHash(orderComponents);

        // restore length of the considerationSansTips array.
        assembly {
            mstore(considerationSansTips, lengthWithTips)
        }

        // Create spentItems array
        SpentItem[] memory spentItems = new SpentItem[](
            orderParameters.offer.length
        );

        // Convert offer to spentItems and add to spentItems array
        for (uint256 j = 0; j < orderParameters.offer.length; j++) {
            spentItems[j] = orderParameters.offer[j].toSpentItem();
        }

        // Create receivedItems array
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            orderParameters.consideration.length
        );

        // Convert consideration to receivedItems and add to receivedItems array
        for (uint256 k = 0; k < orderParameters.consideration.length; k++) {
            receivedItems[k] = orderParameters
                .consideration[k]
                .toReceivedItem();
        }

        // Store orderHash in orderHashes array to pass into zoneParameters
        bytes32[] memory orderHashes = new bytes32[](1);
        orderHashes[0] = orderHash;

        // Create ZoneParameters and add to zoneParameters array
        zoneParameters = ZoneParameters({
            orderHash: orderHash,
            fulfiller: fulfiller,
            offerer: orderParameters.offerer,
            offer: spentItems,
            consideration: receivedItems,
            extraData: advancedOrder.extraData,
            orderHashes: orderHashes,
            startTime: orderParameters.startTime,
            endTime: orderParameters.endTime,
            zoneHash: orderParameters.zoneHash
        });
    }

    function getZoneParameters(
        AdvancedOrder[] memory advancedOrders,
        address fulfiller,
        uint256 maximumFulfilled,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal returns (ZoneParameters[] memory zoneParameters) {
        bytes32[] memory orderHashes = new bytes32[](advancedOrders.length);
        CriteriaResolver[] memory _resolvers = criteriaResolvers;
        // Iterate over advanced orders to calculate orderHashes
        for (uint256 i = 0; i < advancedOrders.length; i++) {
            // Get orderParameters from advancedOrder
            OrderParameters memory orderParameters = advancedOrders[i]
                .parameters;

            // Get orderComponents from orderParameters
            OrderComponents memory orderComponents = OrderComponents({
                offerer: orderParameters.offerer,
                zone: orderParameters.zone,
                offer: orderParameters.offer,
                consideration: orderParameters.consideration,
                orderType: orderParameters.orderType,
                startTime: orderParameters.startTime,
                endTime: orderParameters.endTime,
                zoneHash: orderParameters.zoneHash,
                salt: orderParameters.salt,
                conduitKey: orderParameters.conduitKey,
                counter: SeaportInterface(seaport).getCounter(
                    orderParameters.offerer
                )
            });

            uint256 lengthWithTips = orderComponents.consideration.length;

            ConsiderationItem[] memory considerationSansTips = (
                orderComponents.consideration
            );

            uint256 lengthSansTips = (
                orderParameters.totalOriginalConsiderationItems
            );

            // set proper length of the considerationSansTips array.
            assembly {
                mstore(considerationSansTips, lengthSansTips)
            }

            if (i >= maximumFulfilled) {
                // Set orderHash to 0 if order index exceeds maximumFulfilled
                orderHashes[i] = bytes32(0);
            } else {
                // Get orderHash from orderComponents
                bytes32 orderHash = SeaportInterface(seaport).getOrderHash(
                    orderComponents
                );

                // Add orderHash to orderHashes
                orderHashes[i] = orderHash;
            }

            // restore length of the considerationSansTips array.
            assembly {
                mstore(considerationSansTips, lengthWithTips)
            }
        }

        zoneParameters = new ZoneParameters[](maximumFulfilled);

        // TODO: use testHelpers pattern to use single amount deriver helper
        OrderDetails[] memory orderDetails = (new AmountDeriverHelper())
            .toOrderDetails(advancedOrders, _resolvers);
        // Iterate through advanced orders to create zoneParameters
        for (uint i = 0; i < advancedOrders.length; i++) {
            if (i >= maximumFulfilled) {
                break;
            }
            // Get orderParameters from advancedOrder
            OrderParameters memory orderParameters = advancedOrders[i]
                .parameters;

            // Create ZoneParameters and add to zoneParameters array
            zoneParameters[i] = ZoneParameters({
                orderHash: orderHashes[i],
                fulfiller: fulfiller,
                offerer: orderParameters.offerer,
                offer: orderDetails[i].offer,
                consideration: orderDetails[i].consideration,
                extraData: advancedOrders[i].extraData,
                orderHashes: orderHashes,
                startTime: orderParameters.startTime,
                endTime: orderParameters.endTime,
                zoneHash: orderParameters.zoneHash
            });
        }

        return zoneParameters;
    }
}
