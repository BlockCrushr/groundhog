pragma solidity 0.4.24;

contract IERC948 {

    /// @dev Should return whether the subscriptionHash provided is live on chain, does not know about off chain unconsumed subscriptions
    /// @param subscriptionHash bytes32 hash of the data an owner(s) would have signed to enable subscription transactions
    /// @param subscriptionHashData bytes data of the input agreement
    /// @param signatures bytes signature needs to meet the minimum threshold to be able to transact to be considered valid
    /// call getSubscriptionHash and then call this method with the response and the signatures that you are holding
    /// @return bool, return if the signature matches the incoming hash
    function isValidSubscription(
        bytes32 subscriptionHash,
        bytes subscriptionHashData,
        bytes signatures
    )
    public
    returns (bool isValid);

    function cancelSubscription(
        bytes32 subscriptionHash
    )
    public
    returns (bool success);
}