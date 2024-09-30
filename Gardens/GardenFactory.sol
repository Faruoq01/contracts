// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title GardenFactoryImplementation
    @author BLOK Capital
#####################################################*/

interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

contract GardenFactoryImplementationContract {
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    event GardenDeployed(address indexed deployer, address indexed contractAddress, string id);
    event DeployerAuthorized(address indexed deployer);
    event DeployerRevoked(address indexed deployer);

    // Proxy admins and factory storage
    address[] private admins;
    mapping(address => bool) private isAdmin;
    mapping(address => bool) public authorizedDeployers;
    mapping(address => bool) private upgradeVotes;
    address private proposedFactoryImplementation;
    uint256 private voteCount;

    // garden implementations list
    mapping(address => mapping(string => address)) public gardenProxyContracts;
    mapping(uint256 => address) public gardenImplementationMap;
    address[] public gardenImplementationList;

    modifier onlyAdmin(address _user, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_user, hash, _signature), "Invalid user access");
        require(isAdmin[_user], "Caller is not an admin");
        _;
    }

    function _isValidSignature(address _addr, bytes32 hash, bytes memory _signature) public view returns (bool) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        require((result == MAGIC_VALUE), "Invalid Signature");
        return result == MAGIC_VALUE;
    }

    function authorizeDeployer(address deployer, address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        authorizedDeployers[deployer] = true;
        emit DeployerAuthorized(deployer);
    }

    function revokeDeployer(address deployer, address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        authorizedDeployers[deployer] = false;
        emit DeployerRevoked(deployer);
    }

    function joinFactory(address swaAccount, address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        authorizedDeployers[swaAccount] = true;
        emit DeployerAuthorized(swaAccount);
    }

    function isUserAuthorized(address swaAccount, address _admin, bytes32 hash, bytes memory _signature) 
        external view onlyAdmin(_admin, hash, _signature)  returns(bool)
    {
        return authorizedDeployers[swaAccount];
    }

    function deployGardenProxy(
        bytes memory bytecode,
        string memory gardenId,
        address deployer,
        bytes32 hash, 
        bytes memory _signature
    ) external onlyAdmin(deployer, hash, _signature) returns (address) 
    {
        require(authorizedDeployers[deployer], "Not authorized");

        bytes32 salt = getSalt(deployer, gardenId);
        address computedAddress = getAddress(deployer, bytecode, gardenId);

        // Check if the contract already exists at the computed address
        require(!isContract(computedAddress), "Contract already deployed");

        // Encode the constructor arguments
        bytes memory constructorArgs = abi.encode(deployer);
        
        // Concatenate bytecode and constructor arguments
        bytes memory initCode = abi.encodePacked(bytecode, constructorArgs);

        // Deploy the contract using CREATE2
        address deployedAddress;
        assembly {
            deployedAddress := create2(
                0,
                add(initCode, 0x20), 
                mload(initCode), 
                salt 
            )
            if iszero(extcodesize(deployedAddress)) {
                revert(0, 0)
            }
        }

        gardenProxyContracts[deployer][gardenId] = deployedAddress;
        emit GardenDeployed(deployer, deployedAddress, gardenId);
        return deployedAddress;
    }

    function getAddress(address deployer, bytes memory bytecode, string memory id) public view returns (address) {
        bytes32 salt = getSalt(deployer, id);
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash));
        return address(uint160(uint(hash)));
    }

    function getSalt(address deployer, string memory id) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(deployer, id));
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function getDeployedGardenProxyContract(
        address deployer, 
        string memory gardenId, 
        bytes32 hash, 
        bytes memory _signature
    ) 
        external view onlyAdmin(deployer, hash, _signature) returns (address) 
    {
        require(authorizedDeployers[deployer], "Not authorized");
        return gardenProxyContracts[deployer][gardenId];
    }
}
