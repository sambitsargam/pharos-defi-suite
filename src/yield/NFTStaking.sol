// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  NFTStaking
/// @notice Stake ERC721 NFTs to earn `rewardToken` at a flat rate per NFT per second.
///         Rewards are pre-funded (transfer rewardToken to this contract).
contract NFTStaking is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC721 public immutable nft;
    IERC20 public immutable rewardToken;
    uint256 public rewardPerSecond; // per staked NFT

    struct StakeInfo {
        address owner;
        uint64 since;
    }

    mapping(uint256 => StakeInfo) public stakeOf; // tokenId => stake
    mapping(address => uint256) public stakedCount;

    event Staked(address indexed user, uint256 indexed tokenId);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event Claimed(address indexed user, uint256 indexed tokenId, uint256 amount);

    constructor(address nft_, address rewardToken_, uint256 rewardPerSecond_, address owner_)
        Ownable(owner_)
    {
        nft = IERC721(nft_);
        rewardToken = IERC20(rewardToken_);
        rewardPerSecond = rewardPerSecond_;
    }

    function pending(uint256 tokenId) public view returns (uint256) {
        StakeInfo memory s = stakeOf[tokenId];
        if (s.owner == address(0)) return 0;
        return (block.timestamp - s.since) * rewardPerSecond;
    }

    function stake(uint256 tokenId) external nonReentrant {
        nft.transferFrom(msg.sender, address(this), tokenId);
        stakeOf[tokenId] = StakeInfo({owner: msg.sender, since: uint64(block.timestamp)});
        stakedCount[msg.sender] += 1;
        emit Staked(msg.sender, tokenId);
    }

    function claim(uint256 tokenId) public nonReentrant {
        StakeInfo storage s = stakeOf[tokenId];
        require(s.owner == msg.sender, "not staker");
        uint256 amount = (block.timestamp - s.since) * rewardPerSecond;
        s.since = uint64(block.timestamp);
        if (amount > 0) _payReward(msg.sender, tokenId, amount);
    }

    function unstake(uint256 tokenId) external nonReentrant {
        StakeInfo memory s = stakeOf[tokenId];
        require(s.owner == msg.sender, "not staker");
        uint256 amount = (block.timestamp - s.since) * rewardPerSecond;
        delete stakeOf[tokenId];
        stakedCount[msg.sender] -= 1;
        if (amount > 0) _payReward(msg.sender, tokenId, amount);
        nft.transferFrom(address(this), msg.sender, tokenId);
        emit Unstaked(msg.sender, tokenId);
    }

    function setRewardPerSecond(uint256 r) external onlyOwner {
        rewardPerSecond = r;
    }

    function _payReward(address to, uint256 tokenId, uint256 amount) internal {
        uint256 bal = rewardToken.balanceOf(address(this));
        uint256 pay = amount > bal ? bal : amount;
        rewardToken.safeTransfer(to, pay);
        emit Claimed(to, tokenId, pay);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
