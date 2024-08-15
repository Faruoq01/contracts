// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

contract UpgradeableProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    // Implementation storage
    address public impOwner;
    mapping(address => bool) public authorizedDeployers;
    mapping(address => mapping(string => address)) public gardenProxyContracts;
    
    // Proxy admins
    address[] private admins;
    mapping(address => bool) private isAdmin;
    mapping(address => bool) private upgradeVotes;
    address private proposedImplementation;
    uint256 private voteCount;

    // garden implementations list
    address[] public gardenImplementations;
    uint256 public currentIndex;

    constructor(address[] memory _admins, address _implementation, address[] memory _gardenImplementations) {
        require(_admins.length > 0, "Admins required");
        for (uint256 i = 0; i < _admins.length; i++) {
            _addAdmin(_admins[i]);
        }
        impOwner = address(this);
        _setImplementation(_implementation);
        gardenImplementations = _gardenImplementations;
    }

    modifier onlyAdmin(address _user) {
        require(isAdmin[_user], "Caller is not an admin");
        _;
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
    function addAdmin(address _admin, address _user) external onlyAdmin(_user) {
        _addAdmin(_admin);
    }

    function removeAdmin(address _admin, address _user) external onlyAdmin(_user) {
        _removeAdmin(_admin);
    }

    function proposeUpgrade(address _admin, address _implementation) external onlyAdmin(_admin) {
        require(_implementation != address(0), "Invalid implementation address");
        proposedImplementation = _implementation;
        _resetVotes();
    }

    function voteForUpgrade(address _admin) external onlyAdmin(_admin) {
        require(proposedImplementation != address(0), "No proposed implementation");
        require(!upgradeVotes[_admin], "Already voted");
        upgradeVotes[_admin] = true;
        voteCount++;
    }

    function upgradeTo(address _admin) external onlyAdmin(_admin) {
        require(voteCount == admins.length, "Not all admins have voted");
        _setImplementation(proposedImplementation);
        proposedImplementation = address(0);
        _resetVotes();
    }

    function _resetVotes() private {
        for (uint256 i = 0; i < admins.length; i++) {
            upgradeVotes[admins[i]] = false;
        }
        voteCount = 0;
    }

    function admin(address _admin) external view onlyAdmin(_admin) returns (address[] memory) {
        return _getAdmin();
    }

    function implementation(address _admin) external view onlyAdmin(_admin) returns (address) {
        return _getImplementation();
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

    function getNextGardenImplementationAddress() external returns (uint256) {
        if (gardenImplementations.length == 0) {
            revert("No addresses available");
        }

        // Update the index to the next one in a round-robin fashion
        currentIndex = (currentIndex + 1) % gardenImplementations.length;
        return currentIndex;
    }

    function getCurrentGardenImplementationAddress() external view returns (address) {
        if (gardenImplementations.length == 0) {
            revert("No addresses available");
        }
        return gardenImplementations[currentIndex];
    }

    function getAllGardenImplementationAddresses() external view returns (address[] memory) {
        return gardenImplementations;
    }

    function setGardenImplementationAddresses(address[] memory newAddresses, address _admin) external onlyAdmin(_admin) {
        gardenImplementations = newAddresses;
        currentIndex = 0;
    }

    function _fallback() private {
        _delegate(_getImplementation());
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }
}