// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/MetaMorphoV1_1Factory.sol";

contract BytecodeTest is Test {
    /// @dev The file holds the creation code of MetaMorphoV1_1Factory, deployed on Arbitrum at
    /// 0x878988f5f561081deEa117717052164ea1Ef0c82 in transaction
    /// 0xcee5eb8613d132f0a5010990e03f351694fc3a9aa790ed2c9686d56849165f11, without the constructor argument.
    function testFactoryCreationCodeMatchesArbitrumDeployment() public view {
        bytes memory deployed = vm.parseBytes(vm.readLine("test/helpers/MetaMorphoV1_1FactoryCreationCode.hex"));
        assertEq(deployed, type(MetaMorphoV1_1Factory).creationCode);
    }
}
