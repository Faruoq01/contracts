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

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 amount);
}

interface ISwapRouter03 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
    external
    payable
    returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
    external
    payable
    returns (uint256 amountIn);
}

contract UpgradeableProxy {
    event TokenReceived(address indexed token, address indexed from, uint256 amount);

    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    // Implementation storage
    address public accountOwner;
    address private admin;
    address public gardener;

    /*####################################################
        ERC721 Storage mappings
    #####################################################*/

    // Mapping from token ID to owner address
    mapping(uint256 => address) internal _ownerOf;
    // Mapping owner address to token count
    mapping(address => uint256) internal _balanceOf;
    // Mapping from token ID to approved address
    mapping(uint256 => address) internal _approvals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    constructor(address _admin) {
        _setAdmin(_admin);
        accountOwner = address(this);
    }

    modifier onlyAdmin(address _user) {
        require(admin == _user, "Caller is not an admin");
        _;
    }

    function assignGardener(address _gardener, address _proxy) public onlyAdmin(_proxy) {
        require(_gardener != address(0), "Not a valid address");
        gardener = _gardener;
    }

    function cancelGardener(address _gardener, address _proxy) public onlyAdmin(_proxy) {
        require(_gardener == address(0), "Not a valid address");
        gardener = address(0);
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

    function getTokenBalance(address tokenAddress) external view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(accountOwner);
    }

    function transferERC20(
        address tokenAddress, address recipient, uint256 amount, address _admin
    ) external virtual onlyAdmin(_admin) {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(recipient, amount), "Transfer failed");
        emit TokenReceived(tokenAddress, recipient, amount);
    }

    function swapExactInputSingleHop(
        uint256 amountIn, 
        uint256 amountOutMin, 
        address tokenIn, 
        address tokenOut
    ) 
        external 
        virtual 
    {
        address SWAP_ROUTER_03 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        ISwapRouter03 router = ISwapRouter03(SWAP_ROUTER_03);
        IERC20 ItokenIn = IERC20(tokenIn);

        // Ensure the contract has enough tokens to perform the swap
        require(ItokenIn.balanceOf(address(this)) >= amountIn, "Insufficient token balance in contract");

        // Approve the swap router to spend the specified amount of tokens
        ItokenIn.approve(address(router), amountIn);

        // Set up the parameters for the swap
        ISwapRouter03.ExactInputSingleParams memory params = ISwapRouter03
            .ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000, 
            recipient: address(this), 
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        // Perform the swap
        router.exactInputSingle(params);
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
