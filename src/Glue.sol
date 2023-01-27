// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
/// @title Glue
/// contract for pulling ERC20 tokens to other users on a certain intervals

contract Glue {
    uint256 public constant NO_END_TIME = 0;
    mapping(address => mapping(bytes32 => uint256)) public nextPulls;

    event NewPull(
        address indexed sender, address indexed token, address indexed to, uint256 amount, uint48 interval, uint48 end
    );
    event EndPull(
        address indexed sender, address indexed token, address indexed to, uint256 amount, uint48 interval, uint48 end
    );
    /// @notice pull tokens from an Ethereum address to another one
    /// @param from the address to pull from
    /// @param token the token to pull
    /// @param to the address to forward the tokens
    /// @param amount the amount to pull
    /// @param interval the interval between different pulls
    /// @param end optional end time of the pulls

    function pull(address from, address token, address to, uint256 amount, uint48 interval, uint48 end) external {
        bytes32 id = keccak256(abi.encodePacked(from, token, to, amount, interval, end));
        uint256 nextPull = nextPulls[from][id];
        require(nextPull != 0, "pull-not-approved");
        require(nextPull <= end || end == NO_END_TIME, "pull-expired");
        require(nextPull >= block.timestamp, "pull-too-early");
        nextPulls[from][id] = block.timestamp + interval;
        IERC20(token).transferFrom(from, address(this), amount);
        IERC20(token).transfer(to, amount);
    }
    /// @notice approve a new pull on a certain interval
    /// @param token the token to pull
    /// @param to the address to forward the tokens
    /// @param amount the amount to pull
    /// @param interval the interval between different pulls
    /// @param end optional end time of the pulls

    function approvePull(address token, address to, uint256 amount, uint48 interval, uint48 end) external {
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, to, amount, interval, end));
        require(nextPulls[msg.sender][id] == 0, "pull-already-approved");
        nextPulls[msg.sender][id] = block.timestamp;
        emit NewPull(msg.sender, token, to, amount, interval, end);
    }

    /// @notice end a pull
    /// @param token the token to pull
    /// @param to the address to forward the tokens
    /// @param amount the amount to pull
    /// @param interval the interval between different pulls
    /// @param end optional end time of the pulls
    function endPull(address token, address to, uint256 amount, uint48 interval, uint48 end) external {
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, to, amount, interval, end));
        require(nextPulls[msg.sender][id] != 0, "pull-not-exists");
        nextPulls[msg.sender][id] = 0;
        emit EndPull(msg.sender, token, to, amount, interval, end);
    }
}
