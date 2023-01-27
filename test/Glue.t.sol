// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Glue.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MintableER20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract GlueTest is Test {
    Glue public glue;
    MintableER20 public erc20;

    function setUp() public {
        glue = new Glue();
        erc20 = new MintableER20("Test", "TST");
        vm.warp(123);
    }

    function testApprovePull() public {
        address alice = address(0x1);
        uint256 amount = 100;
        uint48 interval = 1 days;
        uint48 end = 0;
        glue.approvePull(address(erc20), alice, amount, interval, end);

        bytes32 id = keccak256(abi.encodePacked(address(this), address(erc20), alice, amount, interval, end));
        assertEq(glue.nextPulls(address(this), id), block.timestamp);
    }

    function testPull() public returns (address alice, address bob, uint256 amount, uint48 interval, uint48 end) {
        alice = address(0x1);
        bob = address(0x2);

        amount = 100;
        interval = 1 days;
        end = 0;

        // prank bob
        vm.startPrank(bob);
        erc20.approve(address(glue), type(uint256).max);
        glue.approvePull(address(erc20), alice, amount, interval, end);

        bytes32 id = keccak256(abi.encodePacked(bob, address(erc20), alice, amount, interval, end));
        assertEq(glue.nextPulls(bob, id), block.timestamp, "failed-approve-pull");
        erc20.mint(bob, amount);
        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 0);
        glue.pull(bob, address(erc20), alice, amount, interval, end);
        assertEq(erc20.balanceOf(alice), amount);
    }

    function testMultiplePulls() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // more funds
        erc20.mint(address(bob), amount);
        vm.warp(block.timestamp + 1 days);
        glue.pull(bob, address(erc20), alice, amount, interval, end);
        assertEq(erc20.balanceOf(alice), amount * 2);
    }

    function testNotEnoughFunds() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // less funds
        erc20.mint(address(bob), amount - 1);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        glue.pull(bob, address(erc20), alice, amount, interval, end);
        assertEq(erc20.balanceOf(alice), amount);
    }

    function testPullNotApproved() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // modify pull data
        vm.expectRevert("pull-not-approved");
        glue.pull(bob, address(erc20), alice, amount + 1, interval, end);
    }

    function testEndPull() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        bytes32 id = keccak256(abi.encodePacked(bob, address(erc20), alice, amount, interval, end));
        assertTrue(glue.nextPulls(bob, id) > 0);
        // prank bob
        vm.startPrank(bob);
        glue.endPull(address(erc20), alice, amount, interval, end);
        assertEq(glue.nextPulls(bob, id), 0, "failed-end-pull");
    }
}
