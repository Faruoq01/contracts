// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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

contract TransparentUpgradeableProxy {
    address public accountOwner;

    /*####################################################
        ERC721 Storage mappings
    #####################################################*/

    // Mapping from token ID to owner address
    mapping(uint256 => address) internal _ownerOf;
    // Mapping owner address to token count
    mapping(address => uint256) internal _balanceOf;
    // Mapping from token ID to approved address
    mapping(uint256 => address) internal _approvals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        
    bytes32 private constant ADMIN_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    constructor(address _admin) {
        _setAdmin(_admin);
        accountOwner = address(this);
    }

    modifier ifAdmin(address _admin) {
        if (_admin == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }

    function _getAdmin() private view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    function _setAdmin(address _admin) private {
        require(_admin != address(0), "admin = zero address");
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = _admin;
    }

    function _getImplementation() private view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address _implementation) private {
        require(
            _implementation.code.length > 0, "implementation is not contract"
        );
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }

    // Admin interface //
    function changeAdmin(address _admin, address _owner) external ifAdmin(_owner) {
        _setAdmin(_admin);
    }

    function upgradeTo(address _implementation, address _owner) external ifAdmin(_owner) {
        _setImplementation(_implementation);
    }

    function admin(address _owner) external ifAdmin(_owner) returns (address) {
        return _getAdmin();
    }

    function implementation(address _owner) external ifAdmin(_owner) returns (address) {
        return _getImplementation();
    }

    // User interface //
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
        _delegate(_getImplementation());
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}
