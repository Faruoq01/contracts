// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
    
    address[] private admins;
    mapping(address => bool) private isAdmin;
    mapping(address => bool) private upgradeVotes;
    uint256 private voteCount;

    constructor(address[] memory _admins, address _implementation) {
        require(_admins.length > 0, "Admins required");
        for (uint256 i = 0; i < _admins.length; i++) {
            _addAdmin(_admins[i]);
        }
        _setImplementation(_implementation);
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Caller is not an admin");
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
    function addAdmin(address _admin) external onlyAdmin {
        _addAdmin(_admin);
    }

    function removeAdmin(address _admin) external onlyAdmin {
        _removeAdmin(_admin);
    }

    function proposeUpgrade(address _implementation) external onlyAdmin {
        require(_implementation != address(0), "Invalid implementation address");
        upgradeVotes[msg.sender] = true;
        voteCount++;
        if (voteCount == admins.length) {
            _setImplementation(_implementation);
            _resetVotes();
        }
    }

    function _resetVotes() private {
        for (uint256 i = 0; i < admins.length; i++) {
            upgradeVotes[admins[i]] = false;
        }
        voteCount = 0;
    }

    function admin() external view onlyAdmin returns (address[] memory) {
        return _getAdmin();
    }

    function implementation() external view onlyAdmin returns (address) {
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
