pragma solidity ^0.5.0;

import "../common/SecuredTokenTransfer.sol";

import "./Proxy.sol";

/// @title Counter-factual PayingProxy Bootstrap contract
/// A PayingProxy that can also be bootstrapped immediately following creation in one txn
/// A random deployer account is created, this contract is nonce 0 from the transaction that creates the safe
/// Using this Counter-factual address, a second address is generated, this is the safe address
/// the user funds this address, and then this contract is deployed to bootstrap the safe and module creation
/// @author Andrew Redden - <andrew@groundhog.network>
contract PayingProxyBootstrap is SecuredTokenTransfer {

    event ProxyCreation(Proxy proxy);

    /// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    constructor(
        address subModuleMasteryCopy,
        address safeMasterCopy,
        bytes memory moduleSetupData,
        address[] memory owners,
        uint256 threshold,
        address createAddAddr,
        address payable funder,
        address paymentToken,
        uint256 payment
    )
    public
    {
        Proxy module = new Proxy(subModuleMasteryCopy);
        Proxy safe = new Proxy(safeMasterCopy);

        bytes memory createAddData = abi.encodeWithSignature(
            'createNoFactory(address,bytes)', address(module), moduleSetupData
        );

        bytes memory safeSetupData = abi.encodeWithSignature(
            'setup(address[],uint256,address,bytes)', owners, threshold, createAddAddr, createAddData
        );

        assembly {
            if eq(call(gas, safe, 0, add(safeSetupData, 0x20), mload(safeSetupData), 0, 0), 0) {revert(0, 0)}
        }

        emit ProxyCreation(module);
        emit ProxyCreation(safe);
        // no sense bloating chain with a bootstrap contract, make sure you selfdestruct after payment
        if (payment > 0) {
            if (paymentToken == address(0)) {
                // solium-disable-next-line security/no-send
                require(funder.send(payment), "Could not pay safe creation with ether");
            } else {
                require(transferToken(paymentToken, funder, payment), "Could not pay safe creation with token");
            }
        }
//        selfdestruct(funder);
    }
}
