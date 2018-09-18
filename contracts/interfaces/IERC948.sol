pragma solidity 0.4.24;

contract IERC948 {
    /**
    * @dev Should return whether the subscriptionHash provided is live on chain, does not know about off chain unconsumed subscriptions
    * @param subscriptionHash bytes32 hash of the data an owner(s) would have signed to enable subscription transactions
    *
    * MUST return a bool upon valid or invalid signature with corresponding _data
    * MUST take (bytes, bytes) as arguments
    */
    function isValidSubscription(
        bytes32 subscriptionHash
    )
    public
    returns (bool isValid);

    function cancelSubscription(
        bytes32 subscriptionHash
    )
    public
    returns (bool success);
}