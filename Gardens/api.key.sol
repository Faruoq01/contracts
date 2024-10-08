// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

contract APIKeyRegistry {
    // Event for when a new API key is generated
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    event ApiKeyGenerated(address indexed user, bytes32 apiKey);
    
    // Struct to hold information about each API key
    struct ApiKey {
        bytes32 key;
        bool active;
    }

    // Mapping to store API keys per user
    bool public isProtocolActive = true;
    mapping(address => ApiKey) private apiKeys;

    // Modifier to check the protocol kill switch
    modifier _onlyAdmin(address _admin, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_admin, hash, _signature) == MAGIC_VALUE, "Invalid signature");
        require(isProtocolActive, "Protocol unavailable");
        _;
    }

    function _isValidSignature(address _addr, bytes32 hash, bytes memory _signature) public view returns (bytes4) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        return result;
    }

    // Modifier to check if the user has an active key
    modifier hasActiveKey(address _swa) {
        require(apiKeys[_swa].active, "No active API key found");
        _;
    }

    // Function to generate a new API key for a user
    function generateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _onlyAdmin(_swa, hash, _signature) hasActiveKey(_swa) 
    {
        require(apiKeys[_swa].key == 0, "API key already exists");

        // Generate a unique API key based on the user's address and current block timestamp
        bytes32 newApiKey = keccak256(abi.encodePacked(_swa, block.timestamp));

        // Store the generated key and mark it as active
        apiKeys[_swa] = ApiKey({key: newApiKey, active: true});

        // Emit event for new API key generation
        emit ApiKeyGenerated(_swa, newApiKey);
    }

    // Function to deactivate a user's API key
    function deactivateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _onlyAdmin(_swa, hash, _signature) hasActiveKey(_swa)  
    {
        apiKeys[_swa].active = false;
    }

    // Function to activate a user's API key (if it was deactivated)
    function activateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _onlyAdmin(_swa, hash, _signature) hasActiveKey(_swa) 
    {
        require(apiKeys[_swa].key != 0, "API key not found");
        require(!apiKeys[_swa].active, "API key is already active");

        apiKeys[_swa].active = true;
    }

    // Function to check if an API key is valid and active
    function validateApiKey(address user, bytes32 key, bytes32 hash, bytes memory _signature) 
        external _onlyAdmin(user, hash, _signature) hasActiveKey(user)  view returns (bool) 
    {
        return (apiKeys[user].key == key && apiKeys[user].active);
    }

    // Function to retrieve the current API key of a user
    function getApiKey(address user, bytes32 hash, bytes memory _signature) 
        external _onlyAdmin(user, hash, _signature) hasActiveKey(user) view returns (bytes32) 
    {
        return apiKeys[user].key;
    }

    // Function to check if a user has an active API key
    function hasActiveApiKey(address user, bytes32 hash, bytes memory _signature) 
        external _onlyAdmin(user, hash, _signature) hasActiveKey(user) view returns (bool) 
    {
        return apiKeys[user].active;
    }
}
