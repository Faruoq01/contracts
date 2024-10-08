// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract APIKeyRegistry {
    // Event for when a new API key is generated
    event ApiKeyGenerated(address indexed user, bytes32 apiKey);
    
    // Struct to hold information about each API key
    struct ApiKey {
        bytes32 key;
        bool active;
    }

    // Mapping to store API keys per user
    mapping(address => ApiKey) private apiKeys;

    // Modifier to check if the user has an active key
    modifier hasActiveKey(address _swa) {
        require(apiKeys[_swa].active, "No active API key found");
        _;
    }

    // Function to generate a new API key for a user
    function generateApiKey(address _swa) external {
        require(apiKeys[_swa].key == 0, "API key already exists");

        // Generate a unique API key based on the user's address and current block timestamp
        bytes32 newApiKey = keccak256(abi.encodePacked(_swa, block.timestamp));

        // Store the generated key and mark it as active
        apiKeys[_swa] = ApiKey({key: newApiKey, active: true});

        // Emit event for new API key generation
        emit ApiKeyGenerated(_swa, newApiKey);
    }

    // Function to deactivate a user's API key
    function deactivateApiKey(address _swa) external hasActiveKey(_swa) {
        apiKeys[_swa].active = false;
    }

    // Function to activate a user's API key (if it was deactivated)
    function activateApiKey(address _swa) external {
        require(apiKeys[_swa].key != 0, "API key not found");
        require(!apiKeys[_swa].active, "API key is already active");

        apiKeys[_swa].active = true;
    }

    // Function to check if an API key is valid and active
    function validateApiKey(address user, bytes32 key) external view returns (bool) {
        return (apiKeys[user].key == key && apiKeys[user].active);
    }

    // Function to retrieve the current API key of a user
    function getApiKey(address user) external view returns (bytes32) {
        return apiKeys[user].key;
    }

    // Function to check if a user has an active API key
    function hasActiveApiKey(address user) external view returns (bool) {
        return apiKeys[user].active;
    }
}
