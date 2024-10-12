// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title GardenProxy
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

interface IFactory {
    function getGardenImplementationModule(
        uint256 gardenImpModule
    ) external view returns (address);
}

contract UpgradeableGardenProxy {
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 private constant FACTORY_PROXY = bytes32(uint256(keccak256("eip1967.proxy.factory")) - 1);
    bytes32 private constant GARDEN_ADDRESS = bytes32(uint256(keccak256("eip1967.proxy.garden")) - 1);
    bytes32 private constant NFT_ADDRESS = bytes32(uint256(keccak256("eip1967.proxy.nft")) - 1);
    bytes32 private constant GARDEN_IMPLEMENTATION = bytes32(uint256(keccak256("eip1967.proxy.gardenImplementation")) - 1);
    bytes32 private constant API_KEY_REGISTRY = bytes32(uint256(keccak256("eip1967.proxy.apiKey.registry")) - 1);

    constructor(address _admin, address _factory, address _nftID, address _apiKeyRegistry) {
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = _admin;
        StorageSlot.getAddressSlot(FACTORY_PROXY).value = _factory;
        StorageSlot.getAddressSlot(GARDEN_ADDRESS).value = address(this);
        StorageSlot.getAddressSlot(NFT_ADDRESS).value = _nftID;
        StorageSlot.getAddressSlot(API_KEY_REGISTRY).value = _apiKeyRegistry;
    }

    // User interface //
    function _delegate(address _implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
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
        address garden_implementation = StorageSlot.getAddressSlot(GARDEN_IMPLEMENTATION).value;
        if(garden_implementation == address(0)){
            uint256 impModule = _extractKeysFromData(msg.data);
            address factoryAddress = StorageSlot.getAddressSlot(FACTORY_PROXY).value;
            address implementation = IFactory(factoryAddress).getGardenImplementationModule(impModule);
            _delegate(implementation);
            
        }else{
            _delegate(garden_implementation);
        }
    }

    function _extractKeysFromData(bytes memory data) internal pure returns (uint256) {
        require(data.length >= 100, "Insufficient data");

        uint256 impModule;

        assembly {
            impModule := mload(add(data, 0x24))
        }

        return impModule;
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}
