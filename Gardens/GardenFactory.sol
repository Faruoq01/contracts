// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title GardenFactoryImplementation
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

contract GardenFactoryImplementationContract {
    event GardenDeployed(address indexed deployer, address indexed contractAddress, uint256 id);
    event DeployerAuthorized(address indexed deployer);
    event DeployerRevoked(address indexed deployer);

    // storage slots
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

    modifier onlyAdmin(address _admin, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_admin, hash, _signature), "Invalid user access");
        require(isAdmin[_admin], "Caller is not an admin");
        _;
    }

    modifier _validateSignature(address _swa, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_swa, hash, _signature), "Invalid user access");
        _;
    }

    function _isValidSignature(address _addr, bytes32 hash, bytes memory _signature) public view returns (bool) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        require((result == MAGIC_VALUE), "Invalid Signature");
        return result == MAGIC_VALUE;
    }

    /*#####################################
        Admin Interface
    #####################################*/

    function _getAdmin() private view returns (address[] memory) {
        return admins;
    }

    function _addAdmin(address _admin) private {
        require(_admin != address(0), "admin = zero address");
        require(!isAdmin[_admin], "Admin already added");
        isAdmin[_admin] = true;
        admins.push(_admin);
    }

    function _removeAdmin(address _admin) private {
        require(isAdmin[_admin], "Not an admin");
        isAdmin[_admin] = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == _admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
    }

    function addAdmin(address _admin, address _swa, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        _addAdmin(_swa);
    }

    function removeAdmin(address _admin, address _swa, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        _removeAdmin(_swa);
    }

    /*#####################################
        Factory Implementation Interface
    #####################################*/

    function _getFactoryImplementation() private view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address _implementation) private {
        require(
            _implementation.code.length > 0, "implementation is not contract"
        );
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }

    function proposeUpgrade(address _admin, address _implementation, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        require(_implementation != address(0), "Invalid implementation address");
        StorageSlot.getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT).value = _implementation;
        _resetVotes();
    }

    function voteForUpgrade(address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        address _implementation = StorageSlot.getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT).value;
        uint256 _voteCount = StorageSlot.getUint256Slot(VOTE_COUNT).value;
        require(_implementation != address(0), "No proposed implementation");
        require(!upgradeVotes[_admin], "Already voted");
        upgradeVotes[_admin] = true;
        StorageSlot.getUint256Slot(VOTE_COUNT).value = _voteCount++;
    }

    function upgradeTo(address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        address _implementation = StorageSlot.getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT).value;
        uint256 _voteCount = StorageSlot.getUint256Slot(VOTE_COUNT).value;
        require(_voteCount == admins.length, "Not all admins have voted");
        _setImplementation(_implementation);
        StorageSlot.getAddressSlot(PROPOSED_IMPLEMENTATION_CONTRACT).value = address(0);
        _resetVotes();
    }

    function _resetVotes() private {
        for (uint256 i = 0; i < admins.length; i++) {
            upgradeVotes[admins[i]] = false;
        }
        StorageSlot.getUint256Slot(VOTE_COUNT).value = 0;
    }

    function admin(address _admin, bytes32 hash, bytes memory _signature) 
        external view onlyAdmin(_admin, hash, _signature) returns (address[] memory) 
    {
        return _getAdmin();
    }

    function implementation(address _admin, bytes32 hash, bytes memory _signature)  
        external view onlyAdmin(_admin, hash, _signature) returns (address) 
    {
        return _getFactoryImplementation();
    }

    /*#####################################
        Graden Implementation Interface
    #####################################*/

    function setGardenImplementationModule(address _admin, address _implementation, uint256 gardenImpModule, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        require(_admin != address(0), "Invalid address");
        require(_implementation != address(0), "Invalid address");
        gardenImplementationMap[gardenImpModule] = _implementation;
    }

    function getGardenImplementationModule(uint256 gardenImpModule) 
        external view returns (address) 
    {
        return gardenImplementationMap[gardenImpModule];
    }

    function authorizeDeployer(address _admin, address deployer, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    { 
        authorizedDeployers[deployer] = true;
        emit DeployerAuthorized(deployer);
    }

    function revokeDeployer(address _admin, address deployer, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        authorizedDeployers[deployer] = false;
        emit DeployerRevoked(deployer);
    }

    function joinFactory(address swaAccount, bytes32 hash, bytes memory _signature) 
        external _validateSignature(swaAccount, hash, _signature) 
    {
        uint256 userCount = StorageSlot.getUint256Slot(USER_COUNT).value;
        authorizedDeployers[swaAccount] = true;
        deployerId[swaAccount] = userCount + 1;
        userCount++;
        emit DeployerAuthorized(swaAccount);
    }

    function isUserAuthorized(address swaAccount, bytes32 hash, bytes memory _signature) 
        external view _validateSignature(swaAccount, hash, _signature)  returns(bool)
    {
        return authorizedDeployers[swaAccount];
    }

    function getGardenCounts(address swaAccount, bytes32 hash, bytes memory _signature) 
        external view _validateSignature(swaAccount, hash, _signature)  returns(uint256)
    {
        uint256 gardenCount = StorageSlot.getUint256Slot(GARDEN_COUNT).value;
        return gardenCount;
    }

    function getUserCounts(address swaAccount, bytes32 hash, bytes memory _signature) 
        external view _validateSignature(swaAccount, hash, _signature)  returns(uint256)
    {
        uint256 userCount = StorageSlot.getUint256Slot(USER_COUNT).value;
        return userCount;
    }

    function deployGardenProxy(
        bytes memory bytecode,
        address deployer,
        address factory,
        address nft,
        uint256 gardenId,
        bytes32 hash, 
        bytes memory _signature
    ) external _validateSignature(deployer, hash, _signature) returns (address) 
    {
        require(authorizedDeployers[deployer], "Not authorized");

        bytes32 salt = getSalt(deployer, gardenId);
        address computedAddress = getAddress(deployer, bytecode, gardenId);

        // Check if the contract already exists at the computed address
        require(!isContract(computedAddress), "Contract already deployed");

        // Deploy the contract and pass the constructor arguments
        address deployedAddress = _deployProxy(bytecode, factory, deployer, nft, salt);

        gardenProxyContracts[deployer][gardenId] = deployedAddress;

        uint256 gardenCount = StorageSlot.getUint256Slot(GARDEN_COUNT).value;
        StorageSlot.getUint256Slot(GARDEN_COUNT).value = gardenCount++;
        
        gardenCount++;
        emit GardenDeployed(deployer, deployedAddress, gardenId);

        return deployedAddress;
    }

    function _deployProxy(
        bytes memory bytecode,
        address factory, 
        address deployer, 
        address nft, 
        bytes32 salt
    ) internal returns (address) 
    {
        // Encode the constructor arguments (including both deployer and nft)
        bytes memory constructorArgs = abi.encode(deployer, factory, nft);
        
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

        return deployedAddress;
    }

    function getAddress(address deployer, bytes memory bytecode, uint256 gardenId) public view returns (address) {
        bytes32 salt = getSalt(deployer, gardenId);
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash));
        return address(uint160(uint(hash)));
    }

    function getSalt(address deployer, uint256 id) public pure returns (bytes32) {
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
        uint256 gardenId, 
        bytes32 hash, 
        bytes memory _signature
    ) 
        external view onlyAdmin(deployer, hash, _signature) returns (address) 
    {
        require(authorizedDeployers[deployer], "Not authorized");
        return gardenProxyContracts[deployer][gardenId];
    }
}
