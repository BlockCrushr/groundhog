pragma solidity ^0.5.0;

import "./PayingProxy.sol";
import "./Proxy.sol";
/// @title Proxy Factory - Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
/// @author Stefan George - <stefan@gnosis.pm>
contract ProxyFactory {

    bytes proxyByteCode;

    event ProxyCreation(Proxy proxy);
    event PayingProxyCreation(PayingProxy proxy);
    /// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    /// @param masterCopy Address of master copy.
    /// @param data Payload for message call sent to new proxy contract.
    function createProxy(address masterCopy, bytes memory data)
    public
    returns (Proxy proxy)
    {
        proxy = new Proxy(masterCopy);
        if (data.length > 0)
        // solium-disable-next-line security/no-inline-assembly
            assembly {
                if eq(call(gas, proxy, 0, add(data, 0x20), mload(data), 0, 0), 0) { revert(0, 0) }
            }
        emit ProxyCreation(proxy);
    }

    constructor(bytes memory code)
    public
    {
        proxyByteCode = code;
    }

    /// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    /// @param masterCopy Address of master copy.
    /// @param data Payload for message call sent to new proxy contract.
    /// @param funder Address of the funder
    /// @param paymentToken address of the token to repay deployment
    /// @param payment Value of the paymentToken to be paid for deployment
    function createPayingProxy(
        uint256 salt,
        address masterCopy,
        bytes memory data,
        address payable funder,
        address paymentToken,
        uint256 payment
    )
    public
    returns (PayingProxy proxy)
    {
        address payable newProxyAddr;
        bytes memory proxyCode = proxyByteCode;
        assembly {
            newProxyAddr := create2(0, add(proxyCode, 0x20), mload(proxyCode), salt)
            if iszero(extcodesize(newProxyAddr)) {
                revert(0, 0)
            }
        }
        proxy = PayingProxy(newProxyAddr);

        proxy.setup(masterCopy, funder, paymentToken, payment);


        //if we have been passed setup data we want to actually
        //leverage that setup data against our newly established proxy
        if (data.length > 0) {
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                if eq(call(gas, proxy, 0, add(data, 0x20), mload(data), 0, 0), 0) {revert(0, 0)}
            }
        }

        emit PayingProxyCreation(proxy);
    }
}
