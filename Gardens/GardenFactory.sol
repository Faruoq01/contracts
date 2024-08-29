// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title GardenFactory
    @author BLOK Capital
#####################################################*/

contract GardenContractFactory {
    address public impOwner;
    mapping(address => bool) public authorizedDeployers;
    mapping(address => mapping(string => address)) public gardenProxyContracts;

    event GardenDeployed(address indexed deployer, address indexed contractAddress, string id);
    event DeployerAuthorized(address indexed deployer);
    event DeployerRevoked(address indexed deployer);

    function authorizeDeployer(address deployer, address _admin) external {
        require(_admin == impOwner, "Not the owner");
        authorizedDeployers[deployer] = true;
        emit DeployerAuthorized(deployer);
    }

    function revokeDeployer(address deployer, address _admin) external {
        require(_admin == impOwner, "Not the owner");
        authorizedDeployers[deployer] = false;
        emit DeployerRevoked(deployer);
    }

    function joinFactory(address swaAccount, address _admin) external {
        require(_admin == impOwner, "Not the owner");
        authorizedDeployers[swaAccount] = true;
        emit DeployerAuthorized(swaAccount);
    }

    function isUserAuthorized(address swaAccount, address _admin) external view returns(bool) {
        require(_admin == impOwner, "Not the owner");
        return authorizedDeployers[swaAccount];
    }

    // Function to deploy a contract
    function deployGardenProxy(
        bytes memory bytecode,
        string memory gardenId,
        address deployer
    ) external returns (address) {
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
                0, // No value is sent with the deployment
                add(initCode, 0x20), // Skip the length prefix
                mload(initCode), // Length of the init code
                salt // Salt to ensure uniqueness
            )
            // Check if the deployment succeeded
            if iszero(extcodesize(deployedAddress)) {
                revert(0, 0)
            }
        }

        // Store the deployed contract address
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

    function getDeployedGardenProxyContract(address deployer, string memory id, address _admin) external view returns (address) {
        require(_admin == impOwner, "Not the owner");
        require(authorizedDeployers[deployer], "Not authorized");
        return gardenProxyContracts[deployer][id];
    }
}
