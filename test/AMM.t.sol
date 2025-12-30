// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CoopySwapAMMManager} from "../src/AMM.sol";
import {CoopySwapLiquidityPool} from "../src/LiquidityPool.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract AMMTest is Test {
    CoopySwapAMMManager public AMM;

    address constant MOCK_TOKEN_ADDRESS_1 = address(0x11111);
    address constant MOCK_TOKEN_ADDRESS_2 = address(0x22222);

    MockERC20 mockToken1;
    MockERC20 mockToken2;

    function getExpectedDeployAddress() private view returns (address) {
        bytes memory baseByteCode = type(CoopySwapLiquidityPool).creationCode;
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
            address(AMM)
        );

        return expectedCreatedAddress;
    }

    function setUp() public {
        AMM = new CoopySwapAMMManager();

        bytes memory bytecode1 = address(new MockERC20("Token 1", "TKN1", 18))
            .code;
        bytes memory bytecode2 = address(new MockERC20("Token 2", "TKN2", 6))
            .code;

        vm.etch(MOCK_TOKEN_ADDRESS_1, bytecode1);
        vm.etch(MOCK_TOKEN_ADDRESS_2, bytecode2);

        mockToken1 = MockERC20(MOCK_TOKEN_ADDRESS_1);
        mockToken2 = MockERC20(MOCK_TOKEN_ADDRESS_2);
    }

    function test_initializeLP() public {
        address expectedCreatedAddress = getExpectedDeployAddress();

        address newLP = AMM.initializeLP(
            address(mockToken1),
            address(mockToken2)
        );
        CoopySwapLiquidityPool newLPInstance = CoopySwapLiquidityPool(newLP);

        // Deploys the liquidity pool at the expected CREATE2 address
        assertEq(newLP, expectedCreatedAddress);
        // Tokens are in the expected order
        assertEq(newLPInstance.token1(), address(mockToken1));
        assertEq(newLPInstance.token2(), address(mockToken2));
    }

    function test_pairAlreadyExists() public {
        address existingLP = AMM.initializeLP(
            address(mockToken1),
            address(mockToken2)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CoopySwapAMMManager.PairAlreadyExistsError.selector,
                "That liquidity pool already exists!",
                existingLP
            )
        );

        // Passing the tokens in reverse order, the error should still be thrown
        AMM.initializeLP(address(mockToken2), address(mockToken1));
    }
}
