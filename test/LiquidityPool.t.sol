// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CoopySwapPoolFeeVault} from "../src/FeeManager.sol";
import {CoopySwapLiquidityPool} from "../src/LiquidityPool.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract LiquidityPoolTest is Test {
    CoopySwapLiquidityPool public LP;

    address constant MOCK_TOKEN_ADDRESS_1 = address(0x11111);
    address constant MOCK_TOKEN_ADDRESS_2 = address(0x22222);

    MockERC20 mockToken1;
    MockERC20 mockToken2;

    function getExpectedDeployAddress() private view returns (address) {
        bytes memory baseByteCode = type(CoopySwapPoolFeeVault).creationCode;
        bytes memory pairBytes = abi.encode(address(mockToken1), address(mockToken2));
        bytes32 fullInitCodeHash = keccak256(abi.encodePacked(baseByteCode, pairBytes));
        bytes32 tokenPairHash = keccak256(pairBytes);
        address expectedCreatedAddress = vm.computeCreate2Address(tokenPairHash, fullInitCodeHash, address(LP));

        return expectedCreatedAddress;
    }

    function setUp() public {
        bytes memory bytecode1 = address(new MockERC20("Token 1", "TKN1", 18)).code;
        bytes memory bytecode2 = address(new MockERC20("Token 2", "TKN2", 6)).code;

        vm.etch(MOCK_TOKEN_ADDRESS_1, bytecode1);
        vm.etch(MOCK_TOKEN_ADDRESS_2, bytecode2);

        mockToken1 = MockERC20(MOCK_TOKEN_ADDRESS_1);
        mockToken2 = MockERC20(MOCK_TOKEN_ADDRESS_2);

        LP = new CoopySwapLiquidityPool(MOCK_TOKEN_ADDRESS_1, MOCK_TOKEN_ADDRESS_2);
    }

    // TODO more tests
}
