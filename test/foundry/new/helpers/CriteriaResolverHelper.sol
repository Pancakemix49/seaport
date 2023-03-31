// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import { Merkle } from "murky/Merkle.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import { LibSort } from "solady/src/utils/LibSort.sol";

struct CriteriaMetadata {
    uint256 resolvedIdentifier;
    bytes32[] proof;
}

contract CriteriaResolverHelper {
    using LibPRNG for LibPRNG.PRNG;

    uint256 immutable MAX_LEAVES;
    Merkle public immutable MERKLE;

    mapping(uint256 => CriteriaMetadata)
        internal _resolvableIdentifierForGivenCriteria;

    constructor(uint256 maxLeaves) {
        MAX_LEAVES = maxLeaves;
        MERKLE = new Merkle();
    }

    function resolvableIdentifierForGivenCriteria(
        uint256 criteria
    ) public view returns (CriteriaMetadata memory) {
        return _resolvableIdentifierForGivenCriteria[criteria];
    }

    function deriveCriteriaResolvers(
        AdvancedOrder[] memory orders
    ) public view returns (CriteriaResolver[] memory criteriaResolvers) {
        uint256 maxLength;

        for (uint256 i; i < orders.length; i++) {
            AdvancedOrder memory order = orders[i];
            maxLength += (order.parameters.offer.length +
                order.parameters.consideration.length);
        }
        criteriaResolvers = new CriteriaResolver[](maxLength);
        uint256 index;

        for (uint256 i; i < orders.length; i++) {
            AdvancedOrder memory order = orders[i];

            for (uint256 j; j < order.parameters.offer.length; j++) {
                OfferItem memory offerItem = order.parameters.offer[j];
                if (
                    offerItem.itemType == ItemType.ERC721_WITH_CRITERIA ||
                    offerItem.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    CriteriaMetadata
                        memory criteriaMetadata = _resolvableIdentifierForGivenCriteria[
                            offerItem.identifierOrCriteria
                        ];
                    criteriaResolvers[index] = CriteriaResolver({
                        orderIndex: i,
                        index: j,
                        side: Side.OFFER,
                        identifier: criteriaMetadata.resolvedIdentifier,
                        criteriaProof: criteriaMetadata.proof
                    });
                    index++;
                }
            }

            for (uint256 j; j < order.parameters.consideration.length; j++) {
                ConsiderationItem memory considerationItem = order
                    .parameters
                    .consideration[j];
                if (
                    considerationItem.itemType ==
                    ItemType.ERC721_WITH_CRITERIA ||
                    considerationItem.itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    CriteriaMetadata
                        memory criteriaMetadata = _resolvableIdentifierForGivenCriteria[
                            considerationItem.identifierOrCriteria
                        ];
                    criteriaResolvers[index] = CriteriaResolver({
                        orderIndex: i,
                        index: j,
                        side: Side.CONSIDERATION,
                        identifier: criteriaMetadata.resolvedIdentifier,
                        criteriaProof: criteriaMetadata.proof
                    });
                    index++;
                }
            }
        }
        // update actual length
        assembly {
            mstore(criteriaResolvers, index)
        }

        // TODO: read from test context
        // TODO: handle wildcard
    }

    /**
     * @notice Generates a random number of random token identifiers to use as
     *         leaves in a Merkle tree, then hashes them to leaves, and finally
     *         generates a Merkle root and proof for a randomly selected leaf
     * @param prng PRNG to use to generate the criteria metadata
     */
    function generateCriteriaMetadata(
        LibPRNG.PRNG memory prng
    ) public returns (uint256 criteria) {
        uint256[] memory identifiers = generateIdentifiers(prng);

        uint256 selectedIdentifierIndex = prng.next() % identifiers.length;
        uint256 selectedIdentifier = identifiers[selectedIdentifierIndex];
        bytes32[] memory leaves = hashIdentifiersToLeaves(identifiers);
        // TODO: Base Murky impl is very memory-inefficient (O(n^2))
        uint256 resolvedIdentifier = selectedIdentifier;
        criteria = uint256(MERKLE.getRoot(leaves));
        bytes32[] memory proof = MERKLE.getProof(
            leaves,
            selectedIdentifierIndex
        );

        _resolvableIdentifierForGivenCriteria[criteria] = CriteriaMetadata({
            resolvedIdentifier: resolvedIdentifier,
            proof: proof
        });
    }

    /**
     * @notice Generates a random number of random token identifiers to use as
     *         leaves in a Merkle tree
     * @param prng PRNG to use to generate the identifiers
     */
    function generateIdentifiers(
        LibPRNG.PRNG memory prng
    ) public view returns (uint256[] memory identifiers) {
        uint256 numIdentifiers = (prng.next() % MAX_LEAVES);
        if (numIdentifiers <= 1) {
            numIdentifiers = 2;
        }
        identifiers = new uint256[](numIdentifiers);
        for (uint256 i = 0; i < numIdentifiers; ) {
            identifiers[i] = prng.next();
            unchecked {
                ++i;
            }
        }
        bool shouldSort = prng.next() % 2 == 1;
        if (shouldSort) {
            LibSort.sort(identifiers);
        }
    }

    /**
     * @notice Hashes an array of identifiers in-place to use as leaves in a
     *         Merkle tree
     * @param identifiers Identifiers to hash
     */
    function hashIdentifiersToLeaves(
        uint256[] memory identifiers
    ) internal pure returns (bytes32[] memory leaves) {
        assembly {
            leaves := identifiers
        }
        for (uint256 i = 0; i < identifiers.length; ) {
            bytes32 identifier = leaves[i];
            assembly {
                mstore(0x0, identifier)
                identifier := keccak256(0x0, 0x20)
            }
            leaves[i] = identifier;
            unchecked {
                ++i;
            }
        }
    }
}