// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title Garden
    @author BLOK Capital
#####################################################*/

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
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
    address public accountOwner;

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

    
    event Transfer(
        address indexed src, address indexed dst, uint256 indexed tokenId
    );
    event Approval(
        address indexed owner, address indexed spender, uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner, address indexed operator, bool approved
    );

    modifier onlyOwner(address _owner) {
        require(_owner == accountOwner, "Caller is not the owner");
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

    function mint(address dst, uint256 tokenId, address _owner) external onlyOwner(_owner) {
        require(dst != address(0), "Mint to zero address");
        require(_ownerOf[tokenId] == address(0), "Already minted");

        _balanceOf[dst]++;
        _ownerOf[tokenId] = dst;

        emit Transfer(address(0), dst, tokenId);
    }

    function burn(uint256 tokenId, address _owner) external onlyOwner(_owner) {
        require(msg.sender == _ownerOf[tokenId], "Not owner");

        _balanceOf[msg.sender] -= 1;

        delete _ownerOf[tokenId];
        delete _approvals[tokenId];

        emit Transfer(msg.sender, address(0), tokenId);
    }

    receive() external payable {}
}
