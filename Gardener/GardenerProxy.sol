// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title GardenerProxy
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
    address public accountOwner;
    address private admin;
    mapping(string => address) public assignedGardens;
    mapping(address => bool) public isGardenApproved;

    //events
    event CancelGardenerAssinment(address garden);
    event GardenerAssinment(address garden);

    constructor(address _admin) {
        _setAdmin(_admin);
        accountOwner = address(this);
    }

    modifier onlyAdmin(address _user) {
        require(admin == _user, "Caller is not an admin");
        _;
    }

    modifier onlyGarden(address _garden) {
        require(isGardenApproved[_garden], "Caller is not a garden");
        _;
    }

    function assignGardener(address _garden) public {
        require(_garden != address(0), "Garden is not a valid address");
        isGardenApproved[_garden] = false;
        emit GardenerAssinment(_garden);
    }

    function cancelGardenerAssignment(address _garden) public onlyGarden(_garden) {
        isGardenApproved[_garden] = false;
        emit CancelGardenerAssinment(_garden);
    }

    function isActiveGardener(address _garden) public view returns(bool) {
        require(isGardenApproved[_garden], "Caller is not a garden");
        return isGardenApproved[_garden];
    }

    function _getAdmin() private view returns (address) {
        return admin;
    }

    function _setAdmin(address _admin) private {
        require(_admin != address(0), "admin = zero address");
        admin = _admin;
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
    function _addAdmin(address _admin, address proxy) external onlyAdmin(proxy) {
        _setAdmin(_admin);
    }

    function upgradeTo(address _admin, address _implementation) external onlyAdmin(_admin) {
        require(_admin != address(0), "Invalid address");
        _setImplementation(_implementation);
    }

    function getAdmin(address _admin) external view onlyAdmin(_admin) returns (address) {
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
