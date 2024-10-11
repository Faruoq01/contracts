// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*####################################################
    @title API Key Registry
    @author BLOK Capital
#####################################################*/

interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

contract APIKeyRegistry {
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    event ApiKeyGenerated(address indexed user, bytes32 apiKey);
    
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

    function generateApiKey(address _swa, bytes32 hash, bytes memory _signature) 
        external _verifySignature(_swa, hash, _signature) hasActiveKey(_swa) 
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
        external _verifySignature(user, hash, _signature) hasActiveKey(user) view returns (bytes32) 
    {
        return apiKeys[user].key;
    }

    function hasActiveApiKey(address user, bytes32 hash, bytes memory _signature) 
        external _verifySignature(user, hash, _signature) hasActiveKey(user) view returns (bool) 
    {
        return apiKeys[user].active;
    }
}
