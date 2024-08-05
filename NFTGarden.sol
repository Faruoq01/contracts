// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC20 is IERC165 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner)
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

contract TokenBoundAccount is IERC721 is IERC20 {
    // Set the owner of this TBA account
    address public accountOwner;
    
    event Transfer(
        address indexed src, address indexed dst, uint256 indexed id
    );
    event Approval(
        address indexed owner, address indexed spender, uint256 indexed id
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
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*####################################################
        ERC20 token multi-token support Storage mappings
    #####################################################*/

    // Mapping from token address to ERC20 interface
    mapping(address => IERC20) private tokenInterfaces;
    // List of supported tokens
    address[] public supportedTokens;

    constructor(uint256 tokenId) {
        accountOwner = msg.sender;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC20).interfaceId
            || interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function ownerOf(uint256 id) external view returns (address owner) {
        owner = _ownerOf[id];
        require(owner != address(0), "token doesn't exist");
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "owner = zero address");
        return _balanceOf[owner];
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 id) external view returns (address) {
        require(_ownerOf[id] != address(0), "token doesn't exist");
        return _approvals[id];
    }

    function approve(address spender, uint256 id) external {
        address owner = _ownerOf[id];
        require(
            msg.sender == owner || isApprovedForAll[owner][msg.sender],
            "not authorized"
        );
        _approvals[id] = spender;
        emit Approval(owner, spender, id);
    }

    function _isApprovedOrOwner(address owner, address spender, uint256 id)
        internal
        view
        returns (bool)
    {
        return (
            spender == owner || isApprovedForAll[owner][spender]
                || spender == _approvals[id]
        );
    }

    function transferFrom(address src, address dst, uint256 id) public {
        require(src == _ownerOf[id], "src != owner");
        require(dst != address(0), "transfer dst zero address");

        require(_isApprovedOrOwner(src, msg.sender, id), "not authorized");

        _balanceOf[src]--;
        _balanceOf[dst]++;
        _ownerOf[id] = dst;

        delete _approvals[id];

        emit Transfer(src, dst, id);
    }

    function safeTransferFrom(address src, address dst, uint256 id) external {
        transferFrom(src, dst, id);

        require(
            dst.code.length == 0
                || IERC721Receiver(dst).onERC721Received(msg.sender, src, id, "")
                    == IERC721Receiver.onERC721Received.selector,
            "unsafe recipient"
        );
    }

    function safeTransferFrom(
        address src,
        address dst,
        uint256 id,
        bytes calldata data
    ) external {
        transferFrom(src, dst, id);

        require(
            dst.code.length == 0
                || IERC721Receiver(dst).onERC721Received(msg.sender, src, id, data)
                    == IERC721Receiver.onERC721Received.selector,
            "unsafe recipient"
        );
    }

    function mint(address dst, uint256 id) external {
        require(dst != address(0), "mint dst zero address");
        require(_ownerOf[id] == address(0), "already minted");

        _balanceOf[dst]++;
        _ownerOf[id] = dst;

        emit Transfer(address(0), dst, id);
    }

    function burn(uint256 id) external {
        require(msg.sender == _ownerOf[id], "not owner");

        _balanceOf[msg.sender] -= 1;

        delete _ownerOf[id];
        delete _approvals[id];

        emit Transfer(msg.sender, address(0), id);
    }

    // Add a token to the list of supported tokens
    function addSupportedToken(address token) external onlyOwner {
        require(tokenInterfaces[token] == IERC20(address(0)), "Token already supported");
        supportedTokens.push(token);
        tokenInterfaces[token] = IERC20(token);
    }
    
    function deposit(address token, uint256 amount) external onlyOwner{
        require(isSupportedToken(token), "Token not supported");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(isSupportedToken(token), "Token not supported");
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient balance in contract");
        IERC20(token).transfer(msg.sender, amount);
    }
    
    // Get the balance of contract token
    function balanceOf(address token) external view returns (uint256) onlyOwner {
        require(isSupportedToken(token), "Token not supported");
        return IERC20(token).balanceOf(address(this));
    }
    
    // Check if a token is supported
    function isSupportedToken(address token) public view returns (bool) onlyOwner {
        return tokenInterfaces[token] != IERC20(address(0));
    }
}