// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMetaMorphoV1_1} from "./IMetaMorphoV1_1.sol";

/// @title IMetaMorphoV1_1Factory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of MetaMorpho's factory.
interface IMetaMorphoV1_1Factory {
    /// @notice The address of the Morpho contract.
    function MORPHO() external view returns (address);

    /// @notice Whether a MetaMorpho vault was created with the factory.
    function isMetaMorpho(address target) external view returns (bool);

    /// @notice Creates a new MetaMorpho vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the MetaMorpho vault's CREATE2 address.
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorphoV1_1 metaMorpho);
}
