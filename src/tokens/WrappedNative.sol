// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title  WrappedNative (WPHRS)
/// @notice Canonical WETH-style wrapper for the native PHRS gas token. 1 WPHRS == 1 PHRS.
///         Required by AMMs/routers that only handle ERC20s.
contract WrappedNative {
    string public name = "Wrapped PHRS";
    string public symbol = "WPHRS";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);

    /// @notice Wrap native PHRS sent with the call into WPHRS.
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    /// @notice Unwrap `amount` WPHRS back into native PHRS.
    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "WPHRS: insufficient");
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
        emit Withdrawal(msg.sender, amount);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "WPHRS: native transfer failed");
    }

    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "WPHRS: insufficient");
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "WPHRS: allowance");
                allowance[from][msg.sender] = allowed - value;
            }
        }
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }

    receive() external payable {
        deposit();
    }
}
