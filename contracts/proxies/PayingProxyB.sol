pragma solidity ^0.5.0;

import "../common/SecuredTokenTransfer.sol";
/// @title Paying Proxy - Generic proxy contract allows to execute all transactions applying the code of a master contract. It is possible to send along initialization data with the constructor. And sends funds after creation to a specified account.
/// @author Stefan George - <stefan@gnosis.pm>
/// @author Richard Meissner - <richard@gnosis.pm>
/// @author Andrew Redden - <andrew@groundhog.network> - removed delegate proxy as its being populated with a setup function now.
contract PayingProxyB is SecuredTokenTransfer {

    // masterCopy always needs to be first declared variable, to ensure that it is at the same location in the contracts to which calls are delegated.
    address masterCopy;

    constructor(
        address _masterCopy,
        address payable funder,
        address paymentToken,
        uint256 payment
    )
    public
    {
        require(_masterCopy != address(0), "Invalid master copy address provided");
        masterCopy = _masterCopy;

        if (payment > 0) {
            if (paymentToken == address(0)) {
                // solium-disable-next-line security/no-send
                require(funder.send(payment), "Could not pay safe creation with ether");
            } else {
                require(transferToken(paymentToken, funder, payment), "Could not pay safe creation with token");
            }
        }
    }

    /// @dev Fallback function forwards all transactions and returns all received return data.
    function()
    external
    payable
    {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let masterCopy := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas, masterCopy, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {revert(0, returndatasize())}
            return (0, returndatasize())
        }
    }

    function implementation()
    public
    view
    returns (address)
    {
        return masterCopy;
    }

    function proxyType()
    public
    pure
    returns (uint256)
    {
        return 2;
    }
}
