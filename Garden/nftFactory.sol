// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC721/ERC721.sol";
import IERC721 from "./ERC721/IERC721.sol";

contract TokenBoundAccountFactory {
    event TokenBoundAccountCreated(address indexed owner, uint256 indexed tokenId, address account);

    // this is a dictionary that maps multiple tokenIds with their contract address we can interact with each
    // account from zero dev
    mapping(uint256 => address) public nftTokenBoundAccounts;

    // this is a function that zerodev can call to deploy a new nft account and manage its address on a dictionary
    // this address can be retrieved and interacted with from zerodev
    function createNFTTokenBoundAccount(address owner, uint256 tokenId) external returns (address) {
        require(nftTokenBoundAccounts[tokenId] == address(0), "TBA already exists");

        TokenBoundAccount account = new TokenBoundAccount(owner, tokenId);
        nftTokenBoundAccounts[tokenId] = address(account);

        emit TokenBoundAccountCreated(owner, tokenId, address(account));
        return address(account);
    }

    // this function can get a specific token account from its ID
    function getNFTTokenBoundAccount(uint256 tokenId) external view returns (address) {
        return nftTokenBoundAccounts[tokenId];
    }

    // This is an example of how you can get nft balance of an nft owner (specific owner), from a token bound account
    // with tokenId. remember token bound account is a multi nft account mapping multiple owners and their balances
    function getBalanceFromToken(uint256 tokenId, address specificOwner) public returns (uint256) {
        address specificNFTAddress = nftTokenBoundAccounts[tokenId];
        IERC721 nftContract = IERC721(specificNFTAddress);
        uint256 balance = nftContract._balanceOf(specificOwner);
        return balance;
    }
}
