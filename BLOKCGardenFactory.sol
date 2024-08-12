// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GardenContractFactory {
    address public impOwner;
    mapping(address => bool) public authorizedDeployers;
    mapping(address => mapping(string => address)) public userDeployedContracts;

    event ContractDeployed(address indexed deployer, address indexed contractAddress, string id);
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

    function deployContract(bytes memory bytecode, string memory id, address deployer, address _admin) external returns (address) {
        require(_admin == impOwner, "Not the owner");
        require(authorizedDeployers[deployer], "Not authorized");

        // Generate the salt from the deployer address and name
        bytes32 salt = getSalt(deployer, id);

        // Calculate the address of the contract to be deployed
        address computedAddress = getAddress(deployer, bytecode, id);

        // Check if the contract already exists at the computed address
        require(!isContract(computedAddress), "Contract already deployed");

        // Deploy the contract using CREATE2
        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(deployedAddress)) {
                revert(0, 0)
            }
        }

        userDeployedContracts[deployer][id] = deployedAddress;
        emit ContractDeployed(deployer, deployedAddress, id);
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

    function getDeployedContract(address deployer, string memory id, address _admin) external view returns (address) {
        require(_admin == impOwner, "Not the owner");
        require(authorizedDeployers[deployer], "Not authorized");
        return userDeployedContracts[deployer][id];
    }
}
