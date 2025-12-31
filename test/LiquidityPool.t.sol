// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CoopySwapPoolFeeVault} from "../src/FeeManager.sol";
import {CoopySwapLiquidityPool} from "../src/LiquidityPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

// Exposes private functions as public for testing purposes
contract PrivateFunctionHarness is CoopySwapLiquidityPool {
    constructor(
        address token1,
        address token2
    ) CoopySwapLiquidityPool(token1, token2) {}

    function public_checkAllowance(
        MockERC20 token,
        uint256 amountRequested,
        address user
    ) public view {
        _checkAllowance(IERC20(address(token)), amountRequested, user);
    }
}

contract LiquidityPoolTest is Test {
    PrivateFunctionHarness public LP;

    address constant MOCK_TOKEN_ADDRESS_1 = address(0x11111);
    address constant MOCK_TOKEN_ADDRESS_2 = address(0x22222);

    uint8 constant MOCK_TOKEN_1_DECIMALS = 18;
    uint8 constant MOCK_TOKEN_2_DECIMALS = 6;

    MockERC20 mockToken1;
    MockERC20 mockToken2;

    function getExpectedDeployAddress() private view returns (address) {
        bytes memory baseByteCode = type(CoopySwapPoolFeeVault).creationCode;
        bytes memory pairBytes = abi.encode(
            address(mockToken1),
            address(mockToken2)
        );
        bytes32 fullInitCodeHash = keccak256(
            abi.encodePacked(baseByteCode, pairBytes)
        );
        bytes32 tokenPairHash = keccak256(pairBytes);
        address expectedCreatedAddress = vm.computeCreate2Address(
            tokenPairHash,
            fullInitCodeHash,
            address(LP)
        );

        return expectedCreatedAddress;
    }

    function setUp() public {
        bytes memory bytecode1 = address(
            new MockERC20("Token 1", "TKN1", MOCK_TOKEN_1_DECIMALS)
        ).code;
        bytes memory bytecode2 = address(
            new MockERC20("Token 2", "TKN2", MOCK_TOKEN_2_DECIMALS)
        ).code;

        vm.etch(MOCK_TOKEN_ADDRESS_1, bytecode1);
        vm.etch(MOCK_TOKEN_ADDRESS_2, bytecode2);

        mockToken1 = MockERC20(MOCK_TOKEN_ADDRESS_1);
        mockToken2 = MockERC20(MOCK_TOKEN_ADDRESS_2);

        LP = new PrivateFunctionHarness(
            MOCK_TOKEN_ADDRESS_1,
            MOCK_TOKEN_ADDRESS_2
        );
    }

    function test_Constructor() public view {
        address expectedVaultAddress = getExpectedDeployAddress();

        // Fee vault deployed
        assertEq(expectedVaultAddress, address(LP.FeeVault()));
    }

    function test_checkAllowance() public {
        address userAddress = makeAddr("user");

        uint256 amountRequestedToken1 = 1 * 10 ** MOCK_TOKEN_1_DECIMALS;
        uint256 amountRequestedToken2 = 1 * 10 ** MOCK_TOKEN_2_DECIMALS;

        mockToken1.mint(userAddress, amountRequestedToken1);
        mockToken2.mint(userAddress, amountRequestedToken2);

        vm.startPrank(userAddress); // msg.sender will be userAddress instead of the test contract address
        mockToken1.approve(address(LP), amountRequestedToken1);
        mockToken2.approve(address(LP), amountRequestedToken2);

        // Since we're requesting the exact amount, these should not revert
        LP.public_checkAllowance(
            mockToken1,
            amountRequestedToken1,
            userAddress
        );
        LP.public_checkAllowance(
            mockToken2,
            amountRequestedToken2,
            userAddress
        );

        vm.stopPrank();

        address userAddress2 = makeAddr("user2");

        mockToken1.mint(userAddress2, amountRequestedToken1);
        mockToken2.mint(userAddress2, amountRequestedToken2);

        vm.startPrank(userAddress2);
        mockToken1.approve(address(LP), amountRequestedToken1);
        mockToken2.approve(address(LP), amountRequestedToken2);
        vm.stopPrank();

        // These should revert because they're requesting > amount in allowance
        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapLiquidityPool.InsufficientAllowance.selector,
                "You have not approved a sufficiently large allowance"
            )
        );
        vm.prank(userAddress2);
        LP.public_checkAllowance(
            mockToken1,
            amountRequestedToken1 + 1,
            userAddress
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapLiquidityPool.InsufficientAllowance.selector,
                "You have not approved a sufficiently large allowance"
            )
        );
        vm.prank(userAddress2);
        LP.public_checkAllowance(
            mockToken2,
            amountRequestedToken2 + 1,
            userAddress
        );
    }

    // TODO more tests
}
