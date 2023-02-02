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
    MintableER20 public feeToken;

    function setUp() public {
        feeToken = new MintableER20("FeeToken", "FT");
        glue = new Glue(address(feeToken));
        erc20 = new MintableER20("Test", "TST");
        vm.warp(123);
    }

    function testApprovePull() public {
        address alice = address(0x1);
        uint256 amount = 100;
        uint48 interval = 1 days;
        uint48 end = 0;
        uint256 fee = 0;
        glue.approvePull(address(erc20), alice, amount, interval, end, 0, true);

        bytes32 id = keccak256(abi.encodePacked(address(this), address(erc20), alice, amount, interval, end, fee, true));
        assertEq(glue.nextPulls(address(this), id), block.timestamp);
    }

    function _testPull(uint256 fee, bool feeType)
        internal
        returns (address alice, address bob, uint256 amount, uint48 interval, uint48 end)
    {
        alice = address(0x1);
        bob = address(0x2);

        amount = 100;
        interval = 1 days;
        end = 0;

        // prank bob
        vm.startPrank(bob);
        erc20.approve(address(glue), type(uint256).max);
        feeToken.approve(address(glue), type(uint256).max);
        glue.approvePull(address(erc20), alice, amount, interval, end, fee, feeType);

        bytes32 id = keccak256(abi.encodePacked(bob, address(erc20), alice, amount, interval, end, fee, feeType));
        assertEq(glue.nextPulls(bob, id), block.timestamp, "failed-approve-pull");
        erc20.mint(bob, amount);
        if (feeType) erc20.mint(bob, fee);
        else feeToken.mint(bob, fee);

        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 0);
        glue.pull(bob, address(erc20), alice, amount, interval, end, fee, feeType);
        assertEq(erc20.balanceOf(alice), amount);
    }

    function testPull() public returns (address alice, address bob, uint256 amount, uint48 interval, uint48 end) {
        return _testPull(0, true);
    }

    function testMultiplePulls() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // more funds
        erc20.mint(address(bob), amount);
        vm.warp(block.timestamp + 1 days);
        glue.pull(bob, address(erc20), alice, amount, interval, end, 0, true);
        assertEq(erc20.balanceOf(alice), amount * 2);
    }

    function testNotEnoughFunds() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // less funds
        erc20.mint(address(bob), amount - 1);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        glue.pull(bob, address(erc20), alice, amount, interval, end, 0, true);
        assertEq(erc20.balanceOf(alice), amount);
    }

    function testPullNotApproved() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // modify pull data
        vm.expectRevert("pull-not-approved");
        glue.pull(bob, address(erc20), alice, amount + 1, interval, end, 0, true);
    }

    function testEndPull() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        bytes32 id = keccak256(abi.encodePacked(bob, address(erc20), alice, amount, interval, end, uint256(0), true));
        assertTrue(glue.nextPulls(bob, id) > 0);
        // prank bob
        vm.startPrank(bob);
        glue.endPull(address(erc20), alice, amount, interval, end, 0, true);
        assertEq(glue.nextPulls(bob, id), 0, "failed-end-pull");
    }

    function testFee() public {
        uint256 fee = 10;
        assertEq(erc20.balanceOf(address(this)), 0);
        _testPull(fee, true);
        assertEq(erc20.balanceOf(address(this)), fee);
    }

    function testFeeWithFeeToken() public {
        uint256 fee = 10;
        assertEq(erc20.balanceOf(address(this)), 0);
        _testPull(fee, false);
        assertEq(feeToken.balanceOf(address(this)), fee);
    }

    function testPullTooEarly() public {
        (address alice, address bob, uint256 amount, uint48 interval, uint48 end) = testPull();
        // more funds
        erc20.mint(address(bob), amount);
        vm.warp(block.timestamp + 1 days-1);
        vm.expectRevert("pull-too-early");
        glue.pull(bob, address(erc20), alice, amount, interval, end, 0, true);
    }
}
