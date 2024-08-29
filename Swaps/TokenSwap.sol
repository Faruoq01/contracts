// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/*####################################################
    @title GardenTokenSwaps
    @author BLOK Capital
#####################################################*/

abstract contract IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}


/*#######################################
    Single hop swap
########################################*/

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract UniswapV2SingleHopSwap {
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;


    function swapSingleHopExactAmountIn(
        address source,
        uint256 amountIn, 
        uint256 amountOutMin, 
        address tokenIn, 
        address tokenOut
    ) external {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        IERC20 initializeTokenIn = IERC20(tokenIn);
        // IERC20 initializeTokenOut = IERC20(tokenOut);

        initializeTokenIn.transferFrom(source, address(this), amountIn);
        initializeTokenIn.approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        router.swapExactTokensForTokens(
            amountIn, amountOutMin, path, source, block.timestamp
        );
    }

    function swapSingleHopExactAmountOut(
        address source,
        uint256 amountOutDesired,
        uint256 amountInMax,
        address tokenIn,
        address tokenOut
    ) external {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        IERC20 initializeTokenIn = IERC20(tokenIn);
        // IERC20 initializeTokenOut = IERC20(tokenOut);

        initializeTokenIn.transferFrom(source, address(this), amountInMax);
        initializeTokenIn.approve(address(router), amountInMax);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOutDesired, amountInMax, path, source, block.timestamp
        );

        // Refund WETH to msg.sender
        if (amounts[0] < amountInMax) {
            initializeTokenIn.transfer(source, amountInMax - amounts[0]);
        }
    }
}
