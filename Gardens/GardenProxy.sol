// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title GardenProxy
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

contract UpgradeableGardenProxy {
    event TokenReceived(address indexed token, address indexed from, uint256 amount);
    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    // garden contract storage
    address private admin;
    address public gardenAddress;
    address private immutable nftOwership;
    mapping(uint256 => address) public gardenImplementationMap;

    constructor(address _admin, address _nftID) {
        admin = _admin;
        nftOwership = _nftID;
        gardenAddress = address(this);
    }

    modifier onlyAdmin(address _user, bytes32 hash, bytes memory _signature) {
        require(_isValidSignature(_user, hash, _signature), "Invalid user access");
        require(admin == _user, "Caller is not authorized");
        _;
    }

    function _isValidSignature(address _addr, bytes32 hash, bytes memory _signature) public view returns (bool) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        require((result == MAGIC_VALUE), "Invalid Signature");
        return result == MAGIC_VALUE;
    }

    function _getAdmin() private view returns (address) {
        return admin;
    }

    function _setAdmin(address _admin) private {
        require(_admin != address(0), "admin = zero address");
        admin = _admin;
    }

    // Admin interface //
    function _changeAdmin(address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        _setAdmin(_admin);
    }

    function getAdmin(address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) view returns (address) 
    {
        return _getAdmin();
    }

    function setGardenImplementationModule(address _admin, address _implementation, uint256 gardenImpModule, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(_admin, hash, _signature) 
    {
        require(_admin != address(0), "Invalid address");
        require(_implementation != address(0), "Invalid address");
        gardenImplementationMap[gardenImpModule] = _implementation;
    }

    function getGardenImplementationModule(address _admin, uint256 gardenImpModule, bytes32 hash, bytes memory _signature) 
        external view onlyAdmin(_admin, hash, _signature) returns (address) 
    {
        return gardenImplementationMap[gardenImpModule];
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
        uint256 key = _extractKeyFromData(msg.data);
        address implementation = gardenImplementationMap[key];
        _delegate(implementation);
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
