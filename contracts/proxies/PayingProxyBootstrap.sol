pragma solidity ^0.5.0;

import "./PayingProxyB.sol";

/// @title Counter-factual PayingProxy Bootstrap contract
/// A PayingProxy that can also be bootstrapped immediately following creation in one txn
/// A random deployer account is created, this contract is nonce 0 from the transaction that creates the safe
/// Using this Counter-factual address, a second address is generated, this is the safe address
/// the user funds this address, and then this contract is deployed to bootstrap the safe and module creation
/// @author Andrew Redden - <andrew@groundhog.network>
contract PayingProxyBootstrap {

    event ProxyBCreation(PayingProxyB proxy);
    /// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    /// @param masterCopy Address of master copy.
    /// @param data Payload for message call sent to new proxy contract.
    /// @param funder Address of the funder
    /// @param paymentToken address of the token to repay deployment
    /// @param payment Value of the paymentToken to be paid for deployment
    constructor (
        address masterCopy,
        bytes memory data,
        address payable funder,
        address paymentToken,
        uint256 payment
    )
    public
    {
        PayingProxyB proxy = new PayingProxyB(masterCopy, funder, paymentToken, payment);

        if (data.length > 0)
        // solium-disable-next-line security/no-inline-assembly
            assembly {
                if eq(call(gas, proxy, 0, add(data, 0x20), mload(data), 0, 0), 0) { revert(0, 0) }
            }
        emit ProxyBCreation(proxy);

        // no sense bloating chain with a bootstrap contract, make sure you selfdestruct
        selfdestruct(funder);
    }
}
