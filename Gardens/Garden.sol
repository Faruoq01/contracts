// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title Garden Implementation
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

interface IFactory {
    function getGardenImplementationModule(
        uint256 gardenImpModule
    ) external view returns (address);
}

interface ERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4);
}

interface IApiKeyRegistryProxy {
    function validateApiKey(
        address user, 
        bytes32 key, 
        bytes32 hash, 
        bytes memory _signature
    ) external view returns (bool);
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

interface IAavePoolV3 {
    function supply(
        address asset, 
        uint256 amount, 
        address onBehalfOf, 
        uint16 referralCode
    ) external;
}

contract GardenImplementation {
    struct GardenTokenTransfer {
        uint256 gardenImpModule; 
        address tokenAddress; 
        address recipient; 
        uint256 amount; 
        address _admin; 
        bytes32 key; 
        bytes32 hash; 
        bytes _signature;
    }

    struct GardenSwapParams {
        uint256 gardenImpModule;
        uint256 amountIn;
        address tokenIn;
        address tokenOut; 
        address _admin;
        bytes32 key;
        bytes32 hash; 
        bytes _signature;
    }

    struct GardenLendParams {
        uint256 gardenImpModule; 
        address _admin; 
        address tokenIn; 
        uint256 amountIn;
        bytes32 key;
        bytes32 hash; 
        bytes _signature;
    }

    bytes4 public constant MAGIC_VALUE = 0x1626ba7e;
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 private constant FACTORY_PROXY = bytes32(uint256(keccak256("eip1967.proxy.factory")) - 1);
    bytes32 private constant GARDEN_ADDRESS = bytes32(uint256(keccak256("eip1967.proxy.garden")) - 1);
    bytes32 private constant NFT_ADDRESS = bytes32(uint256(keccak256("eip1967.proxy.nft")) - 1);
    bytes32 private constant GARDEN_IMPLEMENTATION = bytes32(uint256(keccak256("eip1967.proxy.gardenImplementation")) - 1);
    bytes32 private constant API_KEY_REGISTRY = bytes32(uint256(keccak256("eip1967.proxy.apiKey.registry")) - 1);

    modifier onlyAdmin(uint256 gardenImpModule, address _user, bytes32 key, bytes32 hash, bytes memory _signature) {
        address admin = StorageSlot.getAddressSlot(ADMIN_SLOT).value;
        address factoryAddress = StorageSlot.getAddressSlot(FACTORY_PROXY).value;
        address implementation = IFactory(factoryAddress).getGardenImplementationModule(gardenImpModule);

        require(implementation != address(0), "Garden implementation not set");
        require(_isValidSignature(_user, hash, _signature), "Invalid user access");
        require(_isValidApiKey(_user, key, hash, _signature), "Invalid access key");
        require(admin == _user, "Caller is not authorized");
        _;
    }

    function _isValidSignature(address _addr, bytes32 hash, bytes memory _signature) public view returns (bool) {
        bytes4 result = ERC1271(_addr).isValidSignature(hash, _signature);
        require((result == MAGIC_VALUE), "Invalid Signature");
        return result == MAGIC_VALUE;
    }

    function _isValidApiKey(address _addr, bytes32 key, bytes32 hash, bytes memory _signature) public view returns (bool) {
        address apiKeyAddress = StorageSlot.getAddressSlot(API_KEY_REGISTRY).value;
        bool result = IApiKeyRegistryProxy(apiKeyAddress).validateApiKey(_addr, key, hash, _signature);
        require(result, "Invalid Signature");
        return result;
    }

    /*#####################################
        Admin Interface
    #####################################*/

    function _getAdmin() private view returns (address) {
        address admin = StorageSlot.getAddressSlot(ADMIN_SLOT).value;
        return admin;
    }

    function _setAdmin(address _admin) private {
        require(_admin != address(0), "admin = zero address");
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = _admin;
    }

    function _changeAdmin(uint256 gardenImpModule, address _admin, bytes32 key, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(gardenImpModule, _admin, key, hash, _signature) 
    {
        _setAdmin(_admin);
    }

    function getAdmin(uint256 gardenImpModule, address _admin, bytes32 key, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(gardenImpModule, _admin, key, hash, _signature) view returns (address) 
    {
        return _getAdmin();
    }

    /*#####################################
        Implementation Interface
    #####################################*/

    function _getFactoryImplementation() private view returns (address) {
        return StorageSlot.getAddressSlot(GARDEN_IMPLEMENTATION).value;
    }

    function _setImplementation(address _implementation) private {
        require(
            _implementation.code.length > 0, "implementation is not contract"
        );
        StorageSlot.getAddressSlot(GARDEN_IMPLEMENTATION).value = _implementation;
    }

    function getImplementation(uint256 gardenImpModule, address _admin, bytes32 key, bytes32 hash, bytes memory _signature)  
        external view onlyAdmin(gardenImpModule, _admin, key, hash, _signature) returns (address) 
    {
        return _getFactoryImplementation();
    }

    function upgradeTo(uint256 gardenImpModule, address _implementation, bytes32 key, address _admin, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(gardenImpModule, _admin, key, hash, _signature) 
    {
        _setImplementation(_implementation);
    }

    /*#####################################
        Defi Interface
    #####################################*/

    function getTokenBalance(uint256 gardenImpModule, address tokenAddress, address _admin, bytes32 key, bytes32 hash, bytes memory _signature) 
        external onlyAdmin(gardenImpModule, _admin, key, hash, _signature) view returns (uint256) 
    {
        IERC20 token = IERC20(tokenAddress);
        address gardenAddress = StorageSlot.getAddressSlot(GARDEN_ADDRESS).value;
        return token.balanceOf(gardenAddress);
    }

    function transferERC20(
        GardenTokenTransfer memory params
    ) external virtual onlyAdmin(params.gardenImpModule, params._admin, params.key, params.hash, params._signature) {
        IERC20 token = IERC20(params.tokenAddress);
        require(token.transfer(params.recipient, params.amount), "Transfer failed");
    }  

    function swapExactInputSingleHop(
        GardenSwapParams memory params
    ) 
        external onlyAdmin(params.gardenImpModule, params._admin, params.key, params.hash, params._signature) 
    {
        // Approve tokens and perform the swap
        _approveAndSwap(params.tokenIn, params.tokenOut, params.amountIn);
    }

    function _approveAndSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {
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
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Perform the swap
        router.exactInputSingle(params);
    }

    function lendToAeve(
        GardenLendParams memory params
    ) 
        external onlyAdmin(params.gardenImpModule, params._admin, params.key, params.hash, params._signature) 
    {
        address POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
        IERC20 ItokenIn = IERC20(params.tokenIn);
        IAavePoolV3 pool = IAavePoolV3(POOL);

        require(ItokenIn.balanceOf(address(this)) >= params.amountIn, "Insufficient token balance in contract");
        ItokenIn.approve(address(pool), params.amountIn);
        pool.supply({
            asset: params.tokenIn,
            amount: params.amountIn,
            onBehalfOf: address(this),
            referralCode: 0
        });
    }
}
