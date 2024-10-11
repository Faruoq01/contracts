// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*####################################################
    @title API Key Registry
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

interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

contract APIKeyRegistry {
    event ApiKeyGenerated(address indexed user, bytes32 apiKey);
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    
    struct ApiKey {
        bytes32 key;
        bool active;
    }

    bool public isProtocolActive = true;
    mapping(address => ApiKey) private apiKeys;

    modifier _verifySignature(address _user, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_user, hash, _signature) == MAGIC_VALUE, "Invalid signature");
        require(isProtocolActive, "Protocol unavailable");
        _;
    }

    function _isValidSignature(address _addr, bytes32 hash, bytes memory _signature) public view returns (bytes4) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        return result;
    }

    modifier hasActiveKey(address _swa) {
        require(apiKeys[_swa].active, "No active API key found");
        _;
    }

    modifier ifAdmin(address _admin, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_admin, hash, _signature) == MAGIC_VALUE, "Invalid user access");
        require(_admin == _getAdmin(), "You are not authorized");
        _;
    }

    /*####################################################
        Admin Interface
    #####################################################*/

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
    function changeAdmin(address _admin, bytes32 hash, bytes memory signature) 
        external ifAdmin(_admin, hash, signature) hasActiveKey(_admin)  
    {
        _setAdmin(_admin);
    }

    function upgradeTo(address _admin, address _implementation, bytes32 hash, bytes memory signature) 
        external ifAdmin(_admin, hash, signature) hasActiveKey(_admin) 
    {
        _setImplementation(_implementation);
    }

    function admin(address _admin, bytes32 hash, bytes memory signature) 
        external ifAdmin(_admin, hash, signature) hasActiveKey(_admin)  view returns (address) 
    {
        return _getAdmin();
    }

    function implementation(address _admin, bytes32 hash, bytes memory signature) 
        external ifAdmin(_admin, hash, signature) hasActiveKey(_admin) view returns (address) 
    {
        return _getImplementation();
    }

    /*####################################################
        API Keys Interface
    #####################################################*/

    function generateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _verifySignature(_swa, hash, _signature)
    {
        require(apiKeys[_swa].key == 0, "API key already exists");

        bytes32 newApiKey = keccak256(abi.encodePacked(_swa, block.timestamp));
        apiKeys[_swa] = ApiKey({key: newApiKey, active: true});
        emit ApiKeyGenerated(_swa, newApiKey);
    }

    function deactivateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _verifySignature(_swa, hash, _signature) hasActiveKey(_swa)  
    {
        apiKeys[_swa].active = false;
    }

    function activateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _verifySignature(_swa, hash, _signature) hasActiveKey(_swa) 
    {
        require(apiKeys[_swa].key != 0, "API key not found");
        require(!apiKeys[_swa].active, "API key is already active");

        apiKeys[_swa].active = true;
    }

    function validateApiKey(address user, bytes32 key, bytes32 hash, bytes memory _signature) 
        external _verifySignature(user, hash, _signature) hasActiveKey(user)  view returns (bool) 
    {
        return (apiKeys[user].key == key && apiKeys[user].active);
    }

    function getApiKey(address user, bytes32 hash, bytes memory _signature) 
        external _verifySignature(user, hash, _signature) view returns (bytes32) 
    {
        return apiKeys[user].key;
    }

    function hasActiveApiKey(address user, bytes32 hash, bytes memory _signature) 
        external _verifySignature(user, hash, _signature) hasActiveKey(user) view returns (bool) 
    {
        return apiKeys[user].active;
    }

    function activateKillSwitch(address user, bytes32 hash, bytes memory _signature) 
        external ifAdmin(user, hash, _signature) 
    {
        isProtocolActive = false;
    }

    function recoverKillSwitch(address user, bytes32 hash, bytes memory _signature) 
        external ifAdmin(user, hash, _signature) 
    {
        isProtocolActive = true;
    }
}
