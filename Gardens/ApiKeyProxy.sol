// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/*####################################################
    @title API Key Registry Proxy
    @author BLOK Capital
#####################################################*/

library StorageSlot {
    struct AddressSlot {
        address value;
    }

    function getAddressSlot(
        bytes32 slot
    ) internal pure returns (AddressSlot storage pointer) {
        assembly {
            pointer.slot := slot
        }
    }
}

contract ApiKeyRegistryProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    constructor(address _admin, address _implementation) {
        require(_admin != address(0), "admin = zero address");
        require(_implementation.code.length > 0, "implementation is not contract");
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = _admin;
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }

    function _delegate(address _implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result :=
                delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _fallback() private {
        address implementation = StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
        _delegate(implementation);
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}
