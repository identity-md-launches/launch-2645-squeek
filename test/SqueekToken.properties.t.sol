// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {SqueekToken} from "src/SqueekToken.sol";

/// @notice Additional boundary and sequence properties for the fixed-supply token.
/// forge-config: default.fuzz.runs = 1024
contract SqueekTokenPropertiesTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    SqueekToken private token;
    address private deployer;
    address private alice;
    address private bob;
    address private spender;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        deployer = makeAddr("properties deployer");
        alice = makeAddr("properties alice");
        bob = makeAddr("properties bob");
        spender = makeAddr("properties spender");
        vm.prank(deployer);
        token = new SqueekToken();
    }

    function test_oneBaseUnitSurvivesDirectAndDelegatedTransfers() public {
        vm.prank(deployer);
        assertTrue(token.transfer(alice, 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, 1));
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 1);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 1));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.balanceOf(deployer), SUPPLY - 1);
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_largestFiniteAllowanceIsNotTreatedAsInfinite() public {
        uint256 approved = type(uint256).max - 1;
        vm.prank(deployer);
        assertTrue(token.approve(spender, approved));
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 1));
        assertEq(token.allowance(deployer, spender), approved - 1);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, bob, SUPPLY - 1));
        assertEq(token.allowance(deployer, spender), approved - SUPPLY);
        assertEq(token.balanceOf(deployer), 0);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteApprovalCanBeReducedAndRevokedAfterUse() public {
        vm.prank(deployer);
        token.approve(spender, type(uint256).max);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 1));
        assertEq(token.allowance(deployer, spender), type(uint256).max);

        vm.prank(deployer);
        assertTrue(token.approve(spender, 2));
        assertEq(token.allowance(deployer, spender), 2);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 1));
        assertEq(token.allowance(deployer, spender), 1);
        vm.prank(deployer);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(deployer, alice, 1);

        assertEq(token.allowance(deployer, spender), 0);
        assertEq(token.balanceOf(deployer), SUPPLY - 2);
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_spentApprovalDoesNotReturnWhenHolderIsRefilled() public {
        vm.prank(deployer);
        token.approve(spender, SUPPLY);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, SUPPLY));
        assertEq(token.allowance(deployer, spender), 0);
        vm.prank(alice);
        assertTrue(token.transfer(deployer, SUPPLY));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(deployer, bob, 1);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.allowance(deployer, spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_approvalIsNotTransitive() public {
        vm.prank(deployer);
        token.approve(alice, 10);
        vm.prank(alice);
        token.approve(bob, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 1));
        vm.prank(bob);
        token.transferFrom(deployer, bob, 1);
        assertEq(token.allowance(deployer, alice), 10);
        assertEq(token.allowance(alice, bob), 10);
        assertEq(token.allowance(deployer, bob), 0);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_approvalsFromDifferentOwnersAreIndependent() public {
        vm.prank(deployer);
        token.transfer(alice, 10);
        vm.prank(deployer);
        token.approve(spender, 7);
        vm.prank(alice);
        token.approve(spender, 4);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 3));
        assertEq(token.allowance(alice, spender), 1);
        assertEq(token.allowance(deployer, spender), 7);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, bob, 7));
        assertEq(token.allowance(alice, spender), 1);
        assertEq(token.allowance(deployer, spender), 0);
        assertEq(token.balanceOf(alice), 7);
        assertEq(token.balanceOf(bob), 10);
        assertEq(token.balanceOf(deployer), SUPPLY - 17);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroApprovalStillRejectsZeroSpender() public {
        vm.prank(deployer);
        token.approve(spender, 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(deployer);
        token.approve(address(0), 0);
        assertEq(token.allowance(deployer, address(0)), 0);
        assertEq(token.allowance(deployer, spender), 1);
        assertEq(token.balanceOf(deployer), SUPPLY);
    }

    function test_zeroDelegatedTransferStillRejectsZeroRecipient() public {
        uint256[3] memory approvals = [uint256(0), 1, type(uint256).max];
        for (uint256 i; i < approvals.length; ++i) {
            vm.prank(deployer);
            token.approve(spender, approvals[i]);
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
            vm.prank(spender);
            token.transferFrom(deployer, address(0), 0);
            assertEq(token.allowance(deployer, spender), approvals[i]);
            assertEq(token.balanceOf(deployer), SUPPLY);
            assertEq(token.balanceOf(address(0)), 0);
            assertEq(token.totalSupply(), SUPPLY);
        }
    }

    function test_maximumDelegatedTransferCannotExceedBalanceEvenToSelf() public {
        vm.prank(deployer);
        token.approve(spender, type(uint256).max);
        address[2] memory recipients = [alice, deployer];
        for (uint256 i; i < recipients.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IERC20Errors.ERC20InsufficientBalance.selector, deployer, SUPPLY, type(uint256).max
                )
            );
            vm.prank(spender);
            token.transferFrom(deployer, recipients[i], type(uint256).max);
            assertEq(token.allowance(deployer, spender), type(uint256).max);
            assertEq(token.balanceOf(deployer), SUPPLY);
            assertEq(token.balanceOf(alice), 0);
            assertEq(token.totalSupply(), SUPPLY);
        }
    }

    function testFuzz_splitDelegatedSpendsExhaustOnlyTheirApproval(uint256 amount, uint256 first) public {
        amount = bound(amount, 1, SUPPLY);
        first = bound(first, 0, amount);
        vm.prank(deployer);
        token.approve(spender, amount);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, first));
        assertEq(token.allowance(deployer, spender), amount - first);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, bob, amount - first));
        assertEq(token.allowance(deployer, spender), 0);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(deployer, alice, 1);
        assertEq(token.balanceOf(deployer), SUPPLY - amount);
        assertEq(token.balanceOf(alice), first);
        assertEq(token.balanceOf(bob), amount - first);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_splitTransfersAndDelegatedReturnHaveNoDust(uint256 amount, uint256 first) public {
        amount = bound(amount, 1, SUPPLY);
        first = bound(first, 0, amount);
        vm.startPrank(deployer);
        assertTrue(token.transfer(alice, first));
        assertTrue(token.transfer(alice, amount - first));
        vm.stopPrank();
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), SUPPLY - amount);

        vm.prank(alice);
        token.approve(spender, amount);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, deployer, amount));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(deployer), SUPPLY);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_underfundedDelegationRollsBackApproval(
        uint256 balance,
        uint256 amount,
        bool infinite,
        bool selfTransfer
    ) public {
        balance = bound(balance, 0, SUPPLY);
        // Keep the finite case strictly below the infinite-allowance sentinel.
        amount = bound(amount, balance + 1, type(uint256).max - 1);
        uint256 approval = infinite ? type(uint256).max : amount;
        vm.prank(deployer);
        token.transfer(alice, balance);
        vm.prank(alice);
        token.approve(spender, approval);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(spender);
        token.transferFrom(alice, selfTransfer ? alice : bob, amount);
        assertEq(token.allowance(alice, spender), approval);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(deployer), SUPPLY - balance);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// @dev All five identity partitions of owner, spender and recipient are checked
    /// for each fuzzed amount, including owner == spender == recipient.
    function testFuzz_delegatedTransfersHandleEveryAddressAlias(uint256 amount, bool infinite) public {
        amount = bound(amount, 0, SUPPLY);
        for (uint256 mode; mode < 5; ++mode) {
            vm.prank(deployer);
            SqueekToken fresh = new SqueekToken();
            address caller = mode == 1 || mode == 4 ? deployer : spender;
            address recipient = mode == 2 || mode == 4 ? deployer : mode == 3 ? spender : alice;
            uint256 approval = infinite ? type(uint256).max : amount;
            vm.prank(deployer);
            fresh.approve(caller, approval);
            vm.expectEmit(true, true, false, true, address(fresh));
            emit Transfer(deployer, recipient, amount);
            vm.prank(caller);
            assertTrue(fresh.transferFrom(deployer, recipient, amount));
            assertEq(fresh.allowance(deployer, caller), infinite ? type(uint256).max : 0);
            assertEq(fresh.balanceOf(deployer), recipient == deployer ? SUPPLY : SUPPLY - amount);
            assertEq(fresh.balanceOf(alice), recipient == alice ? amount : 0);
            assertEq(fresh.balanceOf(spender), recipient == spender ? amount : 0);
            assertEq(fresh.totalSupply(), SUPPLY);
        }
    }
}
