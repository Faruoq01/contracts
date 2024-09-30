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

contract GardenUpgradableProxy {
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    event AdminChanged(address previousAdmin, address newAdmin);
    event Upgraded(address newImplementation);

    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        
    bytes32 private constant ADMIN_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    
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
    uint256 public currentIndex;

    constructor(address[] memory _admins, address _implementation, uint256 gardenImpModule, address _gardenImplementation) {
        require(_admins.length > 0, "Admins required");
        for (uint256 i = 0; i < _admins.length; i++) {
            _addAdmin(_admins[i]);
        }
        _setImplementation(_implementation);
        gardenImplementationList.push(_gardenImplementation);
        gardenImplementationMap[gardenImpModule] = _gardenImplementation; 
    }

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

    function _getFactoryImplementation() private view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address _implementation) private {
        require(
            _implementation.code.length > 0, "implementation is not contract"
        );
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }

    // Admin interface //
    function addAdmin(address _admin, address _user, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_user, hash, _signature) 
    {
        _addAdmin(_admin);
    }

    function removeAdmin(address _admin, address _user, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_user, hash, _signature) 
    {
        _removeAdmin(_admin);
    }

    function proposeUpgrade(address _admin, address _implementation, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        require(_implementation != address(0), "Invalid implementation address");
        proposedFactoryImplementation = _implementation;
        _resetVotes();
    }

    function voteForUpgrade(address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        require(proposedFactoryImplementation != address(0), "No proposed implementation");
        require(!upgradeVotes[_admin], "Already voted");
        upgradeVotes[_admin] = true;
        voteCount++;
    }

    function upgradeTo(address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        require(voteCount == admins.length, "Not all admins have voted");
        _setImplementation(proposedFactoryImplementation);
        proposedFactoryImplementation = address(0);
        _resetVotes();
    }

    function _resetVotes() private {
        for (uint256 i = 0; i < admins.length; i++) {
            upgradeVotes[admins[i]] = false;
        }
        voteCount = 0;
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
        // uint256 key = _extractKeyFromData(msg.data);
        _delegate(_getFactoryImplementation());
    }

    function _extractKeyFromData(bytes memory data) internal pure returns (uint256) {
        require(data.length >= 36, "Insufficient data");
        uint256 key;
        assembly {
            key := mload(add(data, 0x20)) 
        }
        return key;
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}
