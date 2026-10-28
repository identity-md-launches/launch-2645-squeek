// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {SqueekToken} from "../src/SqueekToken.sol";

/// @dev Test-only model of four holders. Every movement stays inside this actor set.
contract SqueekHandler is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    SqueekToken private immutable token;
    address[4] private actors;

    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor(SqueekToken token_, address[4] memory actors_) {
        token = token_;
        actors = actors_;
        expectedBalance[actors_[0]] = SUPPLY;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 amount = bound(amountSeed, 0, expectedBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        expectedBalance[from] -= amount;
        expectedBalance[to] += amount;
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amountSeed) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        // Exercise revocation, both uint256 boundaries, spendable allowances,
        // and unrestricted approvals (an approval need not fit the supply).
        uint256 choice = amountSeed % 5;
        uint256 amount = choice == 0
            ? 0
            : choice == 1
                ? type(uint256).max
                : choice == 2 ? type(uint256).max - 1 : choice == 3 ? bound(amountSeed, 0, SUPPLY) : amountSeed;
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function revoke(uint256 ownerSeed, uint256 spenderSeed) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        vm.prank(owner);
        assertTrue(token.approve(spender, 0));
        expectedAllowance[owner][spender] = 0;
    }

    function transferFrom(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amountSeed) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        address to = _actor(toSeed);
        uint256 allowed = expectedAllowance[owner][spender];
        uint256 available = expectedBalance[owner];
        uint256 amount = bound(amountSeed, 0, available < allowed ? available : allowed);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        expectedBalance[owner] -= amount;
        expectedBalance[to] += amount;
        if (allowed != type(uint256).max) {
            expectedAllowance[owner][spender] -= amount;
        }
    }

    function rejectOverspend(uint256 fromSeed, uint256 toSeed) external {
        address from = _actor(fromSeed);
        uint256 balance = expectedBalance[from];
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, balance + 1)
        );
        vm.prank(from);
        token.transfer(_actor(toSeed), balance + 1);
    }

    function rejectUnapprovedSpend(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        uint256 allowed = expectedAllowance[owner][spender];
        if (allowed == type(uint256).max) return;
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowed, allowed + 1)
        );
        vm.prank(spender);
        token.transferFrom(owner, _actor(toSeed), allowed + 1);
    }

    /// @dev Always drains a funded holder to a different actor, including the last base unit.
    function transferAll(uint256 fromSeed, uint256 toSeed) external {
        address from = _fundedActor(fromSeed);
        address to = _otherActor(from, toSeed);
        uint256 amount = expectedBalance[from];
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        expectedBalance[from] = 0;
        expectedBalance[to] += amount;
    }

    /// @dev Guarantees a nonzero delegated spend. The independent approve/transferFrom
    /// actions above still exercise stale approvals, replacements, and arbitrary ordering.
    function approveAndSpend(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amountSeed, bool infinite)
        external
    {
        address owner = _fundedActor(ownerSeed);
        address spender = _actor(spenderSeed);
        address to = _actor(toSeed);
        uint256 amount = bound(amountSeed, 1, expectedBalance[owner]);
        uint256 approval = infinite ? type(uint256).max : amount;
        vm.prank(owner);
        assertTrue(token.approve(spender, approval));
        assertEq(token.allowance(owner, spender), approval);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        expectedBalance[owner] -= amount;
        expectedBalance[to] += amount;
        expectedAllowance[owner][spender] = infinite ? type(uint256).max : 0;
    }

    /// @dev Two inverse transfers must restore both balances exactly. Check the
    /// intermediate state too, so two broken no-op transfers cannot pass this property.
    function roundTrip(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = _fundedActor(fromSeed);
        address to = _otherActor(from, toSeed);
        uint256 amount = bound(amountSeed, 1, expectedBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        assertEq(token.balanceOf(from), expectedBalance[from] - amount);
        assertEq(token.balanceOf(to), expectedBalance[to] + amount);
        vm.prank(to);
        assertTrue(token.transfer(from, amount));
        assertEq(token.balanceOf(from), expectedBalance[from]);
        assertEq(token.balanceOf(to), expectedBalance[to]);
    }

    function rejectInvalidRecipient(
        uint256 ownerSeed,
        uint256 spenderSeed,
        uint256 amountSeed,
        bool delegated,
        bool infinite
    ) external {
        address owner = _fundedActor(ownerSeed);
        address spender = _actor(spenderSeed);
        uint256 amount = bound(amountSeed, 0, expectedBalance[owner]);
        if (delegated) {
            uint256 approval = infinite ? type(uint256).max : amount;
            vm.prank(owner);
            assertTrue(token.approve(spender, approval));
            expectedAllowance[owner][spender] = approval;
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
            vm.prank(spender);
            token.transferFrom(owner, address(0), amount);
        } else {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
            vm.prank(owner);
            token.transfer(address(0), amount);
        }
    }

    /// @dev Sufficient approval must never bypass the balance check. Reverting after
    /// _spendAllowance must also restore the entire allowance, including at uint256 edges.
    function rejectUnderfundedTransferFrom(
        uint256 ownerSeed,
        uint256 spenderSeed,
        uint256 toSeed,
        uint256 amountSeed,
        bool infinite
    ) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        uint256 balance = expectedBalance[owner];
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max - 1);
        uint256 approval = infinite ? type(uint256).max : amount;
        vm.prank(owner);
        assertTrue(token.approve(spender, approval));
        expectedAllowance[owner][spender] = approval;
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, balance, amount));
        vm.prank(spender);
        token.transferFrom(owner, _actor(toSeed), amount);
    }

    function rejectZeroSpender(uint256 ownerSeed, uint256 amount) external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(_actor(ownerSeed));
        token.approve(address(0), amount);
    }

    function _fundedActor(uint256 seed) private view returns (address) {
        uint256 start = seed % actors.length;
        for (uint256 i; i < actors.length; ++i) {
            address candidate = actors[(start + i) % actors.length];
            if (expectedBalance[candidate] > 0) return candidate;
        }
        revert("model lost the fixed supply");
    }

    function _otherActor(address from, uint256 seed) private view returns (address) {
        uint256 index = seed % actors.length;
        if (actors[index] == from) index = (index + 1) % actors.length;
        return actors[index];
    }

    function _actor(uint256 seed) private view returns (address) {
        return actors[seed % actors.length];
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 128
/// forge-config: default.invariant.fail-on-revert = true
contract SqueekTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    SqueekToken private token;
    SqueekHandler private handler;
    address[4] private actors;

    function setUp() public {
        token = new SqueekToken();
        actors = [makeAddr("holder 0"), makeAddr("holder 1"), makeAddr("holder 2"), makeAddr("holder 3")];
        handler = new SqueekHandler(token, actors);
        token.transfer(actors[0], SUPPLY);

        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = SqueekHandler.transfer.selector;
        selectors[1] = SqueekHandler.approve.selector;
        selectors[2] = SqueekHandler.revoke.selector;
        selectors[3] = SqueekHandler.transferFrom.selector;
        selectors[4] = SqueekHandler.rejectOverspend.selector;
        selectors[5] = SqueekHandler.rejectUnapprovedSpend.selector;
        selectors[6] = SqueekHandler.transferAll.selector;
        selectors[7] = SqueekHandler.approveAndSpend.selector;
        selectors[8] = SqueekHandler.roundTrip.selector;
        selectors[9] = SqueekHandler.rejectInvalidRecipient.selector;
        selectors[10] = SqueekHandler.rejectUnderfundedTransferFrom.selector;
        selectors[11] = SqueekHandler.rejectZeroSpender.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_supplyAndEveryBalanceMatchModel() public view {
        uint256 sum;
        for (uint256 i; i < actors.length; ++i) {
            uint256 actual = token.balanceOf(actors[i]);
            assertEq(actual, handler.expectedBalance(actors[i]));
            sum += actual;
        }
        assertEq(sum, SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
    }

    function invariant_everyAllowanceMatchesModel() public view {
        for (uint256 i; i < actors.length; ++i) {
            assertEq(token.allowance(actors[i], address(0)), 0);
            assertEq(token.allowance(address(0), actors[i]), 0);
            for (uint256 j; j < actors.length; ++j) {
                assertEq(token.allowance(actors[i], actors[j]), handler.expectedAllowance(actors[i], actors[j]));
            }
        }
    }
}
