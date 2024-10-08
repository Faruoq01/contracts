// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/*####################################################
    @title GardenFactoryProxy
    @author BLOK Capital
#####################################################*/

library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    // Function to get the Address slot
    function getAddressSlot(
        bytes32 slot
    ) internal pure returns (AddressSlot storage pointer) {
        assembly {
            pointer.slot := slot
        }
    }

    // Function to get the Uint256 slot
    function getUint256Slot(
        bytes32 slot
    ) internal pure returns (Uint256Slot storage pointer) {
        assembly {
            pointer.slot := slot
        }
    }
}


interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

contract GardenUpgradableFactoryProxy {
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);   
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 private constant PROPOSED_IMPLEMENTATION_CONTRACT = bytes32(uint256(keccak256("eip1967.proxy.proposed.implementation.contract")) - 1);
    bytes32 private constant VOTE_COUNT = bytes32(uint256(keccak256("eip1967.proxy.vote.count")) - 1);
    bytes32 private constant GARDEN_COUNT = bytes32(uint256(keccak256("eip1967.proxy.garden.count")) - 1);
    bytes32 private constant USER_COUNT = bytes32(uint256(keccak256("eip1967.proxy.user.count")) - 1);

    // Proxy admins and factory storage
    address[] private admins;
    mapping(address => bool) private isAdmin;
    mapping(address => bool) public authorizedDeployers;
    mapping(address => uint256) public deployerId;
    mapping(address => bool) private upgradeVotes;

    // garden implementations list
    mapping(address => mapping(uint256 => address)) public gardenProxyContracts;
    mapping(uint256 => address) public gardenImplementationMap;
    address[] public gardenImplementationList;

    constructor(address[] memory _admins, address _implementation, uint256 gardenImpModule, address _gardenImplementation) {
        require(_admins.length > 0, "Admins required");
        for (uint256 i = 0; i < _admins.length; i++) {
            require(_admins[i] != address(0), "admin = zero address");
            require(!isAdmin[_admins[i]], "Admin already added");
            isAdmin[_admins[i]] = true;
            admins.push(_admins[i]);
        }
        
        require( _implementation.code.length > 0, "implementation is not contract");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
        gardenImplementationList.push(_gardenImplementation);
        gardenImplementationMap[gardenImpModule] = _gardenImplementation; 
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
