pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./BasicOrderParametersPointerLibrary.sol";
import { BasicOrderParameters } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillBasicOrderPointer is uint256;

using Scuff for MemoryPointer;
using FulfillBasicOrderPointerLibrary for FulfillBasicOrderPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillBasicOrder(BasicOrderParameters)
library FulfillBasicOrderPointerLibrary {
  enum ScuffKind { parameters_HeadOverflow, parameters_considerationToken_DirtyBits, parameters_considerationToken_MaxValue, parameters_offerer_DirtyBits, parameters_offerer_MaxValue, parameters_zone_DirtyBits, parameters_zone_MaxValue, parameters_offerToken_DirtyBits, parameters_offerToken_MaxValue, parameters_basicOrderType_DirtyBits, parameters_basicOrderType_MaxValue, parameters_additionalRecipients_HeadOverflow, parameters_additionalRecipients_length_DirtyBits, parameters_additionalRecipients_length_MaxValue, parameters_additionalRecipients_element_recipient_DirtyBits, parameters_additionalRecipients_element_recipient_MaxValue, parameters_signature_HeadOverflow }

  enum ScuffableField { parameters }

  bytes4 internal constant FunctionSelector = 0xfb0f3ee1;
  string internal constant FunctionName = "fulfillBasicOrder";
  uint256 internal constant HeadSize = 0x20;
  uint256 internal constant MinimumParametersScuffKind = uint256(ScuffKind.parameters_considerationToken_DirtyBits);
  uint256 internal constant MaximumParametersScuffKind = uint256(ScuffKind.parameters_signature_HeadOverflow);

  /// @dev Convert a `MemoryPointer` to a `FulfillBasicOrderPointer`.
  /// This adds `FulfillBasicOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillBasicOrderPointer) {
    return FulfillBasicOrderPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillBasicOrderPointer` back into a `MemoryPointer`.
  function unwrap(FulfillBasicOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillBasicOrderPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillBasicOrder`to a `FulfillBasicOrderPointer`.
  /// This adds `FulfillBasicOrderPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillBasicOrderPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function call from arguments
  function fromArgs(BasicOrderParameters memory parameters) internal pure returns (FulfillBasicOrderPointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("fulfillBasicOrder((address,uint256,uint256,address,address,address,uint256,uint256,uint8,uint256,uint256,bytes32,uint256,bytes32,bytes32,uint256,(uint256,address)[],bytes))", parameters);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `parameters` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function parametersHead(FulfillBasicOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `BasicOrderParametersPointer` pointing to the data buffer of `parameters`
  function parametersData(FulfillBasicOrderPointer ptr) internal pure returns (BasicOrderParametersPointer) {
    return BasicOrderParametersPointerLibrary.wrap(ptr.unwrap().offset(parametersHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillBasicOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillBasicOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Overflow offset for `parameters`
    directives.push(Scuff.lower(uint256(ScuffKind.parameters_HeadOverflow) + kindOffset, 224, ptr.parametersHead(), positions));
    /// @dev Add all nested directives in parameters
    ptr.parametersData().addScuffDirectives(directives, kindOffset + MinimumParametersScuffKind, positions);
  }

  function getScuffDirectives(FulfillBasicOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.parameters_HeadOverflow) return "parameters_HeadOverflow";
    if (k == ScuffKind.parameters_considerationToken_DirtyBits) return "parameters_considerationToken_DirtyBits";
    if (k == ScuffKind.parameters_considerationToken_MaxValue) return "parameters_considerationToken_MaxValue";
    if (k == ScuffKind.parameters_offerer_DirtyBits) return "parameters_offerer_DirtyBits";
    if (k == ScuffKind.parameters_offerer_MaxValue) return "parameters_offerer_MaxValue";
    if (k == ScuffKind.parameters_zone_DirtyBits) return "parameters_zone_DirtyBits";
    if (k == ScuffKind.parameters_zone_MaxValue) return "parameters_zone_MaxValue";
    if (k == ScuffKind.parameters_offerToken_DirtyBits) return "parameters_offerToken_DirtyBits";
    if (k == ScuffKind.parameters_offerToken_MaxValue) return "parameters_offerToken_MaxValue";
    if (k == ScuffKind.parameters_basicOrderType_DirtyBits) return "parameters_basicOrderType_DirtyBits";
    if (k == ScuffKind.parameters_basicOrderType_MaxValue) return "parameters_basicOrderType_MaxValue";
    if (k == ScuffKind.parameters_additionalRecipients_HeadOverflow) return "parameters_additionalRecipients_HeadOverflow";
    if (k == ScuffKind.parameters_additionalRecipients_length_DirtyBits) return "parameters_additionalRecipients_length_DirtyBits";
    if (k == ScuffKind.parameters_additionalRecipients_length_MaxValue) return "parameters_additionalRecipients_length_MaxValue";
    if (k == ScuffKind.parameters_additionalRecipients_element_recipient_DirtyBits) return "parameters_additionalRecipients_element_recipient_DirtyBits";
    if (k == ScuffKind.parameters_additionalRecipients_element_recipient_MaxValue) return "parameters_additionalRecipients_element_recipient_MaxValue";
    return "parameters_signature_HeadOverflow";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}