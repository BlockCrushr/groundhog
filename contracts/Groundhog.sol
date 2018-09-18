pragma solidity 0.4.24;

import "./common/GEnum.sol";
import "./common/Enum.sol";
import "./GnosisSafe.sol";
import "./interfaces/IERC948.sol";

contract GroundhogWallet is GnosisSafe, IERC948 {

    //keccak256(
    //  "SafeSubTx(address to, uint256 value, bytes data, Enum.Operation operation, uint256 safeTxGas, uint256 dataGas, uint256 gasPrice, address gasToken, bytes meta)"
    //)
    bytes32 public constant SAFE_SUB_TX_TYPEHASH = 0x2a1fd34b6cdf5651c9b7ad3362b2310b9883a1d7010ac9b9a7e26876b9418068;

    event PaymentFailed(bytes32 subHash);

    mapping(bytes32 => Meta) public subscriptions;

    struct Meta {
        GEnum.SubscriptionStatus status;
        uint256 nextWithdraw;
        uint256 offChainID;
        uint256 expires;
    }

    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @param subscriptionHash bytes32 hash of on chain sub
    /// @param subscriptionHashData bytes of the input data that was hashed and agreed to, encodeSubscriptionData
    /// @return bool isValid returns the validity of the subscription
    function isValidSubscription(
        bytes32 subscriptionHash,
        bytes subscriptionHashData,
        bytes signatures
    )
    public
    view
    returns (bool isValid) {
        if(subscriptions[subscriptionHash].status == GEnum.SubscriptionStatus.VALID) {
            return true;
        } else {
            return (checkSignatures(subscriptionHash, subscriptionHashData, signatures, false), "Invalid signatures provided");
        }
        return false;
    }

    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @param subscriptionHash bytes32 hash of on sub to revoke or cancel
    function cancelSubscription(
        bytes32 subscriptionHash
    )
    public
    authorized
    returns (bool) {
        subscriptions[subscriptionHash].status = GEnum.SubscriptionStatus.CANCELLED;
    }

    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @param to Destination address of Safe transaction.
    /// @param value Ether value of Safe transaction.
    /// @param data Data payload of Safe transaction.
    /// @param operation Operation type of Safe transaction.
    /// @param safeTxGas Gas that should be used for the Safe transaction.
    /// @param dataGas Gas costs for data used to trigger the safe transaction and to pay the payment transfer
    /// @param gasPrice Gas price that should be used for the payment calculation.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param meta Packed bytes data {address refundReceiver (required}, {uint256 period (required}, {uint256 offChainID (required}, {uint256 expires (optional}
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    function execSubscription(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        bytes meta,
        bytes signatures
    )
    public
    returns (bool success)
    {
        uint256 startGas = gasleft();

        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation, // Transaction info
            safeTxGas, dataGas, gasPrice, gasToken,
            meta // refundAddress / period / offChainID / expires
        );

        require(checkSignatures(keccak256(subHashData), subHashData, signatures, false), "Invalid signatures provided");

        require(gasleft() >= safeTxGas, "Not enough gas to execute safe transaction");

        require(processSub(keccak256(subHashData), meta), "Unable to Process Subscription");

        // If no safeTxGas has been set and the gasPrice is 0 we assume that all available gas can be used
        success = execute(to, value, data, operation, safeTxGas == 0 && gasPrice == 0 ? gasleft() : safeTxGas);
        if (!success) {
            emit PaymentFailed(keccak256(subHashData));
        }

        // We transfer the calculated tx costs to the refundReceiver to avoid sending it to intermediate contracts that have made calls
        if (gasPrice > 0) {
            super.handlePayment(startGas, dataGas, gasPrice, gasToken, bytesToAddress(meta, 0));
        }
    }


    /// @dev used to help mitigate stack issues
    /// @param subHash bytes32
    /// @param meta bytes packed meta data
    /// @returns bool
    function processSub(
        bytes32 subHash,
        bytes meta // refundAddress / period / offChainID / expires
    )
    internal
    returns (bool) {

        Meta storage sub = subscriptions[subHash];

        if (sub.nextWithdraw != 0) {
            require((subscriptions[subHash].status == GEnum.SubscriptionStatus.VALID && subscriptions[subHash].nextWithdraw >= now), "Withdrawal Not Valid");
        } else {
            sub.status = GEnum.SubscriptionStatus.VALID;
        }

        uint256 period = bytesToUint(meta, 19);

        if (period == uint(GEnum.Period.DAY)) {
            sub.nextWithdraw = now + 1 days;
        } else if (period == uint(GEnum.Period.WEEK)) {
            sub.nextWithdraw = now + 7 days;
        } else if (period == uint(GEnum.Period.MONTH)) {
            sub.nextWithdraw = now + 30 days;
        } else {
            return false;
        }

        if (sub.offChainID == 0) {
            sub.offChainID = bytesToUint(meta, 51);
        }

        //expire set in slot 4, address(20), uint256(32), uint256(32), uint256(32)(optional) 115 length with 0 = 116
        if ((sub.expires == 0 && meta.length == 115)) {
            sub.expires = bytesToUint(meta, 83);
        }

        return true;

    }

    /// @dev Returns hash to be signed by owners.
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @param operation Operation type.
    /// @param safeTxGas Gas that should be used for the safe transaction.
    /// @param dataGas Gas costs for data used to trigger the safe transaction.
    /// @param gasPrice Maximum gas price that should be used for this transaction.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @return Subscription hash.
    function getSubscriptionHash(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        bytes meta // refundAddress / period / offChainID / expires
    )
    public
    view
    returns (bytes32)
    {
        return keccak256(encodeSubscriptionData(to, value, data, operation, safeTxGas, dataGas, gasPrice, gasToken, meta));
    }


    /// @dev Returns the bytes that are hashed to be signed by owners.
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @param operation Operation type.
    /// @param safeTxGas Fas that should be used for the safe transaction.
    /// @param dataGas Gas costs for data used to trigger the safe transaction.
    /// @param gasPrice Maximum gas price that should be used for this transaction.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param meta bytes packed data(refund address, period, offChainID, expires
    /// @return Subscription hash bytes.
    function encodeSubscriptionData(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        bytes meta // refundAddress / period / offChainID / expires
    )
    public
    view
    returns (bytes)
    {

        bytes32 safeSubTxHash = keccak256(
            abi.encode(to, value, keccak256(data), operation, safeTxGas, dataGas, gasPrice, gasToken, meta)
        );
        return abi.encodePacked(byte(0x19), byte(1), domainSeparator, safeSubTxHash);
    }

    /// @dev converts bytes array to uint256
    /// @param _bytes array to splice from
    /// @param _start start position in the array
    /// @return oUint uint256
    function bytesToUint(bytes _bytes, uint _start)
    internal
    pure
    returns (uint256 oUint) {
        require(_bytes.length >= (_start + 32));
        assembly {
            oUint := mload(add(add(_bytes, 0x20), _start))
        }
    }
    /// @dev converts bytes array to address
    /// @param _bytes array to splice from
    /// @param _start start position in the array
    /// @return oAddress address
    function bytesToAddress(bytes _bytes, uint _start)
    internal
    pure
    returns (address oAddress) {
        require(_bytes.length >= (_start + 20));
        assembly {
            oAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }
    }
}
