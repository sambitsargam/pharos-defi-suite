// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title  MerkleDistributor
/// @notice Gas-efficient airdrop. Eligible (index, account, amount) leaves are committed to a
///         Merkle root; recipients claim with a proof. A claimed-bitmap prevents double claims.
contract MerkleDistributor is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;

    mapping(uint256 => uint256) private _claimedBitMap;

    event Claimed(uint256 index, address account, uint256 amount);

    constructor(address token_, bytes32 merkleRoot_, address owner_) Ownable(owner_) {
        token = IERC20(token_);
        merkleRoot = merkleRoot_;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 word = index / 256;
        uint256 bit = index % 256;
        return (_claimedBitMap[word] & (1 << bit)) != 0;
    }

    function _setClaimed(uint256 index) private {
        uint256 word = index / 256;
        uint256 bit = index % 256;
        _claimedBitMap[word] |= (1 << bit);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata proof)
        external
    {
        require(!isClaimed(index), "already claimed");
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(proof, merkleRoot, node), "invalid proof");
        _setClaimed(index);
        token.safeTransfer(account, amount);
        emit Claimed(index, account, amount);
    }

    /// @notice Owner reclaims unclaimed tokens after the campaign.
    function sweep(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
