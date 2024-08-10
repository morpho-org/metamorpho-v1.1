// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

contract DeploymentTest is IntegrationTest {
    function testSetName(string memory name) public {
        vm.prank(OWNER);
        vault.setName(name);

        assertEq(vault.name(), name);
    }

    function testSetNameNotOwner(string memory name) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.setName(name);
    }

    function testSetSymbol(string memory symbol) public {
        vm.prank(OWNER);
        vault.setSymbol(symbol);

        assertEq(vault.symbol(), symbol);
    }

    function testSetSymbolNotOwner(string memory name) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.setName(name);
    }

    function testDeployMetaMorphoAddresssZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        createMetaMorpho(OWNER, address(0), ConstantsLib.MIN_TIMELOCK, address(loanToken), "MetaMorpho Vault", "MMV");
    }

    function testDeployMetaMorphoNotToken(address notToken) public {
        vm.assume(address(notToken) != address(loanToken));
        vm.assume(address(notToken) != address(collateralToken));
        vm.assume(address(notToken) != address(vault));

        vm.expectRevert();
        createMetaMorpho(OWNER, address(morpho), ConstantsLib.MIN_TIMELOCK, notToken, "MetaMorpho Vault", "MMV");
    }

    function testDeployMetaMorpho(
        address owner,
        address morpho,
        uint256 initialTimelock,
        string memory name,
        string memory symbol
    ) public {
        assumeNotZeroAddress(owner);
        assumeNotZeroAddress(morpho);
        initialTimelock = bound(initialTimelock, ConstantsLib.MIN_TIMELOCK, ConstantsLib.MAX_TIMELOCK);

        IMetaMorpho newVault = createMetaMorpho(owner, morpho, initialTimelock, address(loanToken), name, symbol);

        assertEq(newVault.owner(), owner, "owner");
        assertEq(address(newVault.MORPHO()), morpho, "morpho");
        assertEq(newVault.timelock(), initialTimelock, "timelock");
        assertEq(newVault.asset(), address(loanToken), "asset");
        assertEq(newVault.name(), name, "name");
        assertEq(newVault.symbol(), symbol, "symbol");
        assertEq(loanToken.allowance(address(newVault), address(morpho)), type(uint256).max, "loanToken allowance");
    }
}
