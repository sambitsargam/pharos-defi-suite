// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title  MultiSigWallet
/// @notice An m-of-n multisig. Owners submit transactions; once `required` owners confirm,
///         anyone can execute them. Holds native PHRS and can call any contract.
contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmed;

    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId, address indexed to, uint256 value);
    event Confirm(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx !exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "executed");
        _;
    }

    constructor(address[] memory owners_, uint256 required_) {
        require(owners_.length > 0 && required_ > 0 && required_ <= owners_.length, "bad config");
        for (uint256 i; i < owners_.length; i++) {
            address o = owners_[i];
            require(o != address(0) && !isOwner[o], "bad owner");
            isOwner[o] = true;
            owners.push(o);
        }
        required = required_;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function ownerCount() external view returns (uint256) {
        return owners.length;
    }

    function transactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function submit(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (uint256 txId)
    {
        txId = transactions.length;
        transactions.push(
            Transaction({to: to, value: value, data: data, executed: false, confirmations: 0})
        );
        emit Submit(txId, to, value);
    }

    function confirm(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(!confirmed[txId][msg.sender], "already confirmed");
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;
        emit Confirm(msg.sender, txId);
    }

    function revoke(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(confirmed[txId][msg.sender], "not confirmed");
        confirmed[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;
        emit Revoke(msg.sender, txId);
    }

    function execute(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage t = transactions[txId];
        require(t.confirmations >= required, "not enough confirmations");
        t.executed = true;
        (bool ok,) = t.to.call{value: t.value}(t.data);
        require(ok, "tx failed");
        emit Execute(txId);
    }
}
