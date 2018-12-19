pragma solidity ^0.5.0;

import "../base/Module.sol";
import "../base/OwnerManager.sol";
import "../common/GEnum.sol";
import "../common/SignatureDecoder.sol";
import "../external/BokkyPooBahsDateTimeLibrary.sol";
import "../external/SafeMath.sol";

/// @title SubscriptionModule - A module with support for Subscription Payments
/// @author Andrew Redden - <andrew@groundhog.network>
contract SubscriptionModule is Module, SignatureDecoder {

    using BokkyPooBahsDateTimeLibrary for uint;

    using SafeMath for uint;
    string public constant NAME = "Groundhog";
    string public constant VERSION = "0.0.1";
    bytes32 public domainSeparator;


    //keccak256(
    //    "EIP712Domain(address verifyingContract)"
    //);
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;

    //keccak256(
    //  "SafeSubTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken,address refundAddress,bytes meta)"
    //)
    bytes32 public constant SAFE_SUB_TX_TYPEHASH = 0x180e6fe977456676413d21594ff72b84df056409812ba2e51d28187117f143c2;

    mapping(bytes32 => Meta) public subscriptions;

    struct Meta {
        GEnum.SubscriptionStatus status;
        uint256 nextWithdraw;
        uint256 offChainID;
        uint256 expires;
    }

    event PaymentFailed(bytes32 subscriptionHash);
    event ProcessingFailed();

    /// @dev Setup function sets manager
    function setup()
    public
    {
        require(setManager() && domainSeparator == 0, "Domain Separator already set!");
        domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, this));
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
    /// @param refundAddress payout address or 0 if tx.origin
    /// @param meta Packed bytes data {address refundReceiver (required}, {uint256 period (required}, {uint256 offChainID (required}, {uint256 expires (optional}
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    /// @return success boolean value of execution

    function execSubscription(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes meta,
        bytes calldata signatures
    )
    public
    returns (bool success)
    {
        uint256 startGas = gasleft();

        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation, // Transaction info
            safeTxGas, dataGas, gasPrice, gasToken, refundAddress,
            meta
        );

        require(gasleft() >= safeTxGas, "Not enough gas to execute safe transaction");

        require(checkHash(keccak256(subHashData), signatures), "Invalid signatures provided");

        success = paySubscription(to, value, data, operation, keccak256(subHashData), meta);
        // If no safeTxGas has been set and the gasPrice is 0 we assume that all available gas can be used

        if (!success) {
            emit PaymentFailed(keccak256(subHashData));
        }

        // We transfer the calculated tx costs to the refundReceiver to avoid sending it to intermediate contracts that have made calls
        if (gasPrice > 0) {
            handleTxPayment(startGas, dataGas, gasPrice, gasToken, refundAddress);
        }

    }

    function processMeta(bytes meta)
    internal
    pure
    returns (uint256[3] outMeta) {
        uint256 period;
        uint256 offChainID;
        uint256 expire;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            period := mload(add(meta, add(0x20, 0)))
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            offChainID := mload(add(meta, add(0x20, 32)))
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            expire := mload(add(meta, add(0x20, 64)))
        }
        return [period, offChainID, expire];
    }


    function paySubscription(address to, uint256 value, bytes data, Enum.Operation operation, bytes32 subHash, bytes meta)
    internal
    returns (bool success) {

        success = processSub(subHash, processMeta(meta));

        success = manager.execTransactionFromModule(to, value, data, operation);
    }

    function handleTxPayment(
        uint256 gasUsed,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver
    )
    internal
    {
        uint256 amount = ((gasUsed - gasleft()) + dataGas) * gasPrice;
        // solium-disable-next-line security/no-tx-origin
        address receiver = refundReceiver == address(0) ? tx.origin : refundReceiver;
        if (gasToken == address(0)) {
            // solium-disable-next-line security/no-send
            require(manager.execTransactionFromModule(receiver, amount, "0x", Enum.Operation.Call), "Could not execute payment");
        } else {
            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", receiver, amount);
            // solium-disable-next-line security/no-inline-assembly
            require(manager.execTransactionFromModule(gasToken, 0, data, Enum.Operation.Call), "Could not execute payment in specified gasToken");
        }
    }


    function checkHash(bytes32 transactionHash, bytes signatures)
    internal
    view
    returns (bool valid) {
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint256 i;
        uint256 threshold = OwnerManager(manager).getThreshold();
        // Validate threshold is reached.
        valid = false;
        for (i = 0; i < threshold; i++) {
            currentOwner = recoverKey(transactionHash, signatures, i);
            require(OwnerManager(manager).isOwner(currentOwner), "Signature not provided by owner");
            require(currentOwner > lastOwner, "Signatures are not ordered by owner address");
            lastOwner = currentOwner;
        }
        valid = true;
    }


    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @param subscriptionHash bytes32 hash of on chain sub
    /// @return bool isValid returns the validity of the subscription
    function isValidSubscription(
        bytes32 subscriptionHash,
        bytes signatures
    )
    public
    view
    returns (bool isValid) {
        if (subscriptions[subscriptionHash].status == GEnum.SubscriptionStatus.VALID) {
            return true;
        } else if (subscriptions[subscriptionHash].status == GEnum.SubscriptionStatus.EXPIRED) {
            require(subscriptions[subscriptionHash].expires != 0, "Invalid Expiration Set");
            return (now <= subscriptions[subscriptionHash].expires);
        } else if (subscriptions[subscriptionHash].status == GEnum.SubscriptionStatus.INIT) {
            return checkHash(subscriptionHash, signatures);
        }
        return false;
    }

    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @return bool hash of on sub to revoke or cancel
    function cancelSubscription(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address refundAddress,
        bytes meta,
        bytes signatures
    )
    public
    returns (bool) {


        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation, // Transaction info
            safeTxGas, dataGas, gasPrice, gasToken, refundAddress,
            meta
        );
        require(subscriptions[keccak256(subHashData)].status != GEnum.SubscriptionStatus.CANCELLED, "Subscription is already cancelled");

        require(checkHash(keccak256(subHashData), signatures), "Invalid signatures provided");

        Meta storage sub = subscriptions[keccak256(subHashData)];
        sub.status = GEnum.SubscriptionStatus.CANCELLED;

        return true;
    }

    /// @dev used to help mitigate stack issues
    /// @return bool
    function processSub(
        bytes32 subHash,
        uint256[3] pmeta
    )
    internal
    returns (bool) {
        uint256 period = pmeta[0];
        uint256 offChainID = pmeta[1];
        uint256 expires = pmeta[2];
        Meta storage sub = subscriptions[subHash];

        require((sub.status != GEnum.SubscriptionStatus.EXPIRED || sub.status != GEnum.SubscriptionStatus.CANCELLED), "Subscription Invalid");


        if (sub.status == GEnum.SubscriptionStatus.INIT) {

            sub.status = GEnum.SubscriptionStatus.VALID;
            sub.nextWithdraw = now;

            if (expires != 0) {
                sub.expires = expires;
            }

            if (offChainID != 0) {
                sub.offChainID = offChainID;
            }
        }

        require(((sub.status == GEnum.SubscriptionStatus.VALID && now >= sub.nextWithdraw) && BokkyPooBahsDateTimeLibrary.diffMinutes()), "Withdraw Cooldown");

        if (period == uint(GEnum.Period.DAY)) {
            sub.nextWithdraw = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 1);
        } else if (period == uint(GEnum.Period.WEEK)) {
            sub.nextWithdraw = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 7);
        } else if (period == uint(GEnum.Period.MONTH)) {
            sub.nextWithdraw = BokkyPooBahsDateTimeLibrary.addMonths(sub.nextWithdraw, 1);
        } else {
            revert(string(abi.encodePacked(period)));
        }

        //if a subscription is expiring and its next withdraw timeline is beyond hte time of the expiration
        //modify the status
        if (sub.expires != 0 && sub.nextWithdraw > sub.expires) {
            sub.status = GEnum.SubscriptionStatus.EXPIRED;
        }
        return true;
    }


    function getSubscriptionMetaBytes(
        uint256 period,
        uint256 offChainID,
        uint256 expires
    )
    public
    pure
    returns (bytes) {
        return abi.encodePacked(period, offChainID, expires);
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
    /// @param meta bytes refundAddress / period / offChainID / expires
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
        address refundAddress,
        bytes meta // period / offChainID / expires
    )
    public
    view
    returns (bytes32)
    {
        return keccak256(encodeSubscriptionData(to, value, data, operation, safeTxGas, dataGas, gasPrice, gasToken, refundAddress, meta));
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
        address refundAddress,
        bytes meta
    )
    public
    view
    returns (bytes)
    {

        bytes32 safeSubTxHash = keccak256(
            abi.encode(SAFE_SUB_TX_TYPEHASH, to, value, keccak256(data), operation, safeTxGas, dataGas, gasPrice, gasToken, refundAddress, keccak256(meta))
        );
        return abi.encodePacked(byte(0x19), byte(1), domainSeparator, safeSubTxHash);
    }

    /// @dev Allows to estimate a Safe transaction.
    ///      This method is only meant for estimation purpose, therfore two different protection mechanism against execution in a transaction have been made:
    ///      1.) The method can only be called from the safe itself
    ///      2.) The response is returned with a revert
    ///      When estimating set `from` to the address of the safe.
    ///      Since the `estimateGas` function includes refunds, call this method to get an estimated of the costs that are deducted from the safe with `execTransaction`
    /// @param to Destination address of Safe transaction.
    /// @param value Ether value of Safe transaction.
    /// @param data Data payload of Safe transaction.
    /// @param operation Operation type of Safe transaction.
    /// @return Estimate without refunds and overhead fees (base transaction and payload data gas costs).
    function requiredTxGas(address to, uint256 value, bytes memory data, Enum.Operation operation, bytes meta)
    public
    authorized
    returns (uint256)
    {
        uint256 startGas = gasleft();
        // We don't provide an error message here, as we use it to return the estimate
        // solium-disable-next-line error-reason

        uint256[3] memory pMeta = processMeta(meta);
        require(manager.execTransactionFromModule(to, value, data, operation));
        uint256 requiredGas = startGas - gasleft();
        // Convert response to string and return via error message
        revert(string(abi.encodePacked(requiredGas)));

    }
}
