// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CoopySwapPoolFeeVault} from "../src/FeeManager.sol";
import {CoopySwapLiquidityPool} from "../src/LiquidityPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

// Exposes private functions as public for testing purposes
contract PrivateFunctionHarness is CoopySwapLiquidityPool {
    constructor(address token1, address token2) CoopySwapLiquidityPool(token1, token2) {}

    function public_checkAllowance(MockERC20 token, uint256 amountRequested, address user) public view {
        _checkAllowance(IERC20(address(token)), amountRequested, user);
    }

    function public_checkBalance(MockERC20 token, uint256 amountRequested, address user) public view {
        _checkBalance(IERC20(address(token)), amountRequested, user);
    }

    function public_performTransfer(address from, address to, IERC20 token, uint256 amount) public {
        _performTransfer(from, to, token, amount);
    }
}

contract LiquidityPoolTest is Test {
    PrivateFunctionHarness public LP;

    struct GrantUserTestTokensResponse {
        address userAddress;
        uint256 amountGrantedToken1;
        uint256 amountGrantedToken2;
    }

    address constant MOCK_TOKEN_ADDRESS_1 = address(0x11111);
    address constant MOCK_TOKEN_ADDRESS_2 = address(0x22222);

    uint8 constant MOCK_TOKEN_1_DECIMALS = 18;
    uint8 constant MOCK_TOKEN_2_DECIMALS = 6;

    MockERC20 mockToken1;
    MockERC20 mockToken2;

    function giveUserTokens(uint256 amountToken1, uint256 amountToken2, string memory userAddressName)
        private
        returns (GrantUserTestTokensResponse memory)
    {
        address userAddress = makeAddr(userAddressName);

        uint256 amountGrantedToken1 = amountToken1 * 10 ** MOCK_TOKEN_1_DECIMALS;
        uint256 amountGrantedToken2 = amountToken2 * 10 ** MOCK_TOKEN_2_DECIMALS;

        mockToken1.mint(userAddress, amountGrantedToken1);
        mockToken2.mint(userAddress, amountGrantedToken2);

        vm.startPrank(userAddress); // msg.sender will be userAddress instead of the test contract address
        mockToken1.approve(address(LP), amountGrantedToken1);
        mockToken2.approve(address(LP), amountGrantedToken2);
        vm.stopPrank();

        return GrantUserTestTokensResponse(userAddress, amountGrantedToken1, amountGrantedToken2);
    }

    function getExpectedDeployAddress() private view returns (address) {
        bytes memory baseByteCode = type(CoopySwapPoolFeeVault).creationCode;
        bytes memory pairBytes = abi.encode(address(mockToken1), address(mockToken2));
        bytes32 fullInitCodeHash = keccak256(abi.encodePacked(baseByteCode, pairBytes));
        bytes32 tokenPairHash = keccak256(pairBytes);
        address expectedCreatedAddress = vm.computeCreate2Address(tokenPairHash, fullInitCodeHash, address(LP));

        return expectedCreatedAddress;
    }

    function addLiquidity(uint8 token1Amount, uint8 token2Amount) private {
        GrantUserTestTokensResponse memory testData = giveUserTokens(token1Amount, token2Amount, "user");
        vm.prank(testData.userAddress);
        LP.provideLiquidity(testData.amountGrantedToken1, testData.amountGrantedToken2);
    }

    function setUp() public {
        bytes memory bytecode1 = address(new MockERC20("Token 1", "TKN1", MOCK_TOKEN_1_DECIMALS)).code;
        bytes memory bytecode2 = address(new MockERC20("Token 2", "TKN2", MOCK_TOKEN_2_DECIMALS)).code;

        vm.etch(MOCK_TOKEN_ADDRESS_1, bytecode1);
        vm.etch(MOCK_TOKEN_ADDRESS_2, bytecode2);

        mockToken1 = MockERC20(MOCK_TOKEN_ADDRESS_1);
        mockToken2 = MockERC20(MOCK_TOKEN_ADDRESS_2);

        LP = new PrivateFunctionHarness(MOCK_TOKEN_ADDRESS_1, MOCK_TOKEN_ADDRESS_2);
    }

    function test_Constructor() public view {
        address expectedVaultAddress = getExpectedDeployAddress();

        // Fee vault deployed
        assertEq(expectedVaultAddress, address(LP.FeeVault()));
    }

    function test_checkAllowance() public {
        GrantUserTestTokensResponse memory testData = giveUserTokens(1, 1, "user");

        vm.startPrank(testData.userAddress); // msg.sender will be userAddress instead of the test contract address
        // Since we're requesting the exact amount, these should not revert
        LP.public_checkAllowance(mockToken1, testData.amountGrantedToken1, testData.userAddress);
        LP.public_checkAllowance(mockToken2, testData.amountGrantedToken2, testData.userAddress);
        vm.stopPrank();

        GrantUserTestTokensResponse memory testData2 = giveUserTokens(1, 1, "user2");
        // These should revert because they're requesting > amount in allowance
        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapLiquidityPool.InsufficientAllowance.selector,
                "You have not approved a sufficiently large allowance"
            )
        );
        vm.prank(testData2.userAddress);
        LP.public_checkAllowance(mockToken1, testData2.amountGrantedToken1 + 1, testData2.userAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapLiquidityPool.InsufficientAllowance.selector,
                "You have not approved a sufficiently large allowance"
            )
        );
        vm.prank(testData2.userAddress);
        LP.public_checkAllowance(mockToken2, testData2.amountGrantedToken2 + 1, testData2.userAddress);
    }

    function test_checkBalance() public {
        GrantUserTestTokensResponse memory testData = giveUserTokens(1, 1, "user");

        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapLiquidityPool.InsufficientBalance.selector,
                "You do not have enough of those tokens to execute the transaction"
            )
        );
        vm.prank(testData.userAddress);
        LP.public_checkBalance(mockToken1, testData.amountGrantedToken1 + 1, testData.userAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapLiquidityPool.InsufficientBalance.selector,
                "You do not have enough of those tokens to execute the transaction"
            )
        );
        vm.prank(testData.userAddress);
        LP.public_checkBalance(mockToken2, testData.amountGrantedToken2 + 1, testData.userAddress);
    }

    function test_performTransfer() public {
        GrantUserTestTokensResponse memory testData = giveUserTokens(1, 1, "user");

        LP.public_performTransfer(
            testData.userAddress, address(this), IERC20(address(mockToken1)), testData.amountGrantedToken1
        );
        LP.public_performTransfer(
            testData.userAddress, address(this), IERC20(address(mockToken2)), testData.amountGrantedToken2
        );

        // Should fail because we've already done this transfer, user should not have enough remaining balance
        vm.expectRevert("Token transfer failed");
        LP.public_performTransfer(
            testData.userAddress, address(this), IERC20(address(mockToken1)), testData.amountGrantedToken1
        );
    }

    function test_provideLiquidity_revertWhenNoLiquidityProvided() public {
        // Errors out with 0 token1 liquidity
        vm.expectRevert(
            abi.encodeWithSelector(CoopySwapLiquidityPool.BadInput.selector, "You can't provide zero liquidity")
        );
        LP.provideLiquidity(0, 1);

        vm.expectRevert(
            abi.encodeWithSelector(CoopySwapLiquidityPool.BadInput.selector, "You can't provide zero liquidity")
        );
        // Errors out with 0 token2 liquidity
        LP.provideLiquidity(1, 0);
    }

    function test_provideLiquidity_initialLiquidity() public {
        GrantUserTestTokensResponse memory testData = giveUserTokens(2, 2, "user");

        vm.prank(testData.userAddress);
        LP.provideLiquidity(testData.amountGrantedToken1, testData.amountGrantedToken2);

        // Assert liquidity NFT minted
        assertEq(LP.balanceOf(testData.userAddress), 1);
    }

    function test_provideLiquidity_slippageTooHigh() public {
        // Provide initial liquidity
        addLiquidity(200, 200);

        // Should revert due to high slippage (0.5%)
        GrantUserTestTokensResponse memory testData2 = giveUserTokens(200, 198, "user");
        vm.expectRevert(abi.encodeWithSelector(CoopySwapLiquidityPool.SlippageTooHigh.selector));
        vm.prank(testData2.userAddress);
        LP.provideLiquidity(testData2.amountGrantedToken1, testData2.amountGrantedToken2);
    }

    function test_provideLiquidity_subsequentLiquidity() public {
        // Provide initial liquidity
        addLiquidity(200, 200);

        // Should NOT revert due to high slippage, as it uses a price very close to the current one
        GrantUserTestTokensResponse memory testData = giveUserTokens(200, 199, "user2");
        vm.prank(testData.userAddress);
        LP.provideLiquidity(testData.amountGrantedToken1, testData.amountGrantedToken2);
    }
    // TODO more tests
}
