// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 amount);
}

interface ISwapRouter02 {
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
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract TokenBoundAccount is IERC721 {
    // Set the owner of this TBA account
    address public accountOwner;
    address constant SWAP_ROUTER_02 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    ISwapRouter02 private constant router = ISwapRouter02(SWAP_ROUTER_02);

    event TokenReceived(address indexed token, address indexed from, uint256 amount);
    
    event Transfer(
        address indexed src, address indexed dst, uint256 indexed tokenId
    );
    event Approval(
        address indexed owner, address indexed spender, uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner, address indexed operator, bool approved
    );

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
    mapping(address => mapping(address => bool)) public override isApprovedForAll;

    constructor(address _owner) {
        accountOwner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == accountOwner, "Caller is not the owner");
        _;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function ownerOf(uint256 tokenId) external view override returns (address owner) {
        owner = _ownerOf[tokenId];
        require(owner != address(0), "Token doesn't exist");
    }

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "Owner = zero address");
        return _balanceOf[owner];
    }

    function setApprovalForAll(address operator, bool approved) external override {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        require(_ownerOf[tokenId] != address(0), "Token doesn't exist");
        return _approvals[tokenId];
    }

    function approve(address spender, uint256 tokenId) external override {
        address owner = _ownerOf[tokenId];
        require(
            msg.sender == owner || isApprovedForAll[owner][msg.sender],
            "Not authorized"
        );
        _approvals[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function _isApprovedOrOwner(address owner, address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return (
            spender == owner || isApprovedForAll[owner][spender]
                || spender == _approvals[tokenId]
        );
    }

    function transferFrom(address src, address dst, uint256 tokenId) public override {
        require(src == _ownerOf[tokenId], "Src != owner");
        require(dst != address(0), "Transfer to zero address");

        require(_isApprovedOrOwner(src, msg.sender, tokenId), "Not authorized");

        _balanceOf[src]--;
        _balanceOf[dst]++;
        _ownerOf[tokenId] = dst;

        delete _approvals[tokenId];

        emit Transfer(src, dst, tokenId);
    }

    function safeTransferFrom(address src, address dst, uint256 tokenId) external override {
        transferFrom(src, dst, tokenId);

        require(
            dst.code.length == 0
                || IERC721Receiver(dst).onERC721Received(msg.sender, src, tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
            "Unsafe recipient"
        );
    }

    function safeTransferFrom(
        address src,
        address dst,
        uint256 tokenId,
        bytes calldata data
    ) external override {
        transferFrom(src, dst, tokenId);

        require(
            dst.code.length == 0
                || IERC721Receiver(dst).onERC721Received(msg.sender, src, tokenId, data)
                    == IERC721Receiver.onERC721Received.selector,
            "Unsafe recipient"
        );
    }

    function mint(address dst, uint256 tokenId) external onlyOwner {
        require(dst != address(0), "Mint to zero address");
        require(_ownerOf[tokenId] == address(0), "Already minted");

        _balanceOf[dst]++;
        _ownerOf[tokenId] = dst;

        emit Transfer(address(0), dst, tokenId);
    }

    function burn(uint256 tokenId) external onlyOwner {
        require(msg.sender == _ownerOf[tokenId], "Not owner");

        _balanceOf[msg.sender] -= 1;

        delete _ownerOf[tokenId];
        delete _approvals[tokenId];

        emit Transfer(msg.sender, address(0), tokenId);
    }

    function getTokenBalance(address tokenAddress) external view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

    function transferERC20(address tokenAddress, address recipient, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(recipient, amount), "Transfer failed");
        emit TokenReceived(tokenAddress, recipient, amount);
    }

    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 feePercentage,
        address sender,
        address recipient
    ) external onlyOwner returns (ISwapRouter02.ExactInputSingleParams memory) {
        uint24 feeTier = convertFeePercentageToTier(feePercentage);

        uint256 feeAmount = calculateFee(amountIn, feeTier);
        require(amountIn > feeAmount, "Insufficient amount to cover fee");
        uint256 amountAfterFee = amountIn - feeAmount;

        IERC20(tokenIn).transferFrom(sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(router), amountIn);

        // Set up parameters for the swap
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: feeTier,
            recipient: recipient,
            amountIn: amountAfterFee,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        router.exactInputSingle(params);

        return params;
    }

    function convertFeePercentageToTier(uint256 feePercentage) public pure returns (uint24) {
        return uint24(feePercentage * 10000);
    }

    function calculateFee(uint256 amountIn, uint24 fee) public pure returns (uint256) {
        return (amountIn * fee) / 10000;
    }


    fallback() external payable {}
    receive() external payable {}
}
