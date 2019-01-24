pragma solidity ^0.5.0;

import "../base/Module.sol";
import "../base/OwnerManager.sol";
import "../common/GEnum.sol";
import "../common/SignatureDecoder.sol";
import "../external/BokkyPooBahsDateTimeLibrary.sol";
import "../external/Math.sol";
import "../OracleRegistry.sol";

/// @title SubscriptionModule - A module with support for Subscription Payments
/// @author Andrew Redden - <andrew@groundhog.network>
contract SubscriptionModule is Module, SignatureDecoder {

    using BokkyPooBahsDateTimeLibrary for uint;
    using DSMath for uint;
    string public constant NAME = "Groundhog";
    string public constant VERSION = "0.0.1";
    bytes32 public domainSeparator;
    address public oracleRegistry;

    //keccak256(
    //    "EIP712Domain(address verifyingContract, string NAME, string VERSION)"
    //);
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;

    //keccak256(
    //  "SafeSubTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes meta)"
    //)
    bytes32 public constant SAFE_SUB_TX_TYPEHASH = 0x4494907805e3ceba396741b2837174bdf548ec2cbe03f5448d7fa8f6b1aaf98e;

    mapping(bytes32 => Meta) public subscriptions;

    struct Meta {
        GEnum.SubscriptionStatus status;
        uint256 nextWithdraw;
        uint256 offChainID;
        uint256 expires;
    }

    event PaymentFailed(bytes32 subscriptionHash);
    event ProcessingFailed();
    event DynamicPayment(uint256 conversionRate, uint256 paymentTotal);
    event SubscriptionCancelled(bytes32 subHash);
    event SubscriptionProcessed(bytes32 subHash);

    /// @dev Setup function sets manager
    function setup(address _oracleRegistry)
    public
    {
        setManager();
        require(domainSeparator == 0, "VALID_STATE: DOMAIN_SEPARATOR_SET");
        domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, address(this)));
        require(oracleRegistry == address(0), "VALID_STATE: MKRDAO_FEED_SET");
        oracleRegistry = _oracleRegistry;
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
    /// @param refundReceiver payout address or 0 if tx.origin
    /// @param meta Packed bytes data {address refundReceiver (required}, {uint256 period (required}, {uint256 offChainID (required}, {uint256 expires (optional}
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    /// @return success boolean value of execution

    function execSubscription(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory meta,
        bytes memory signatures
    )
    public
    payable
    {
        uint256 startGas = gasleft();

        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation, // Transaction info
            safeTxGas, dataGas, gasPrice, gasToken, refundReceiver,
            meta
        );

        require(gasleft() >= safeTxGas, "INVALID_DATA: WALLET_TX_GAS");

        require(checkHash(keccak256(subHashData), signatures), "INVALID_DATA: SIGNATURES");

        paySubscription(to, value, data, operation, keccak256(subHashData), meta);

        // We transfer the calculated tx costs to the refundReceiver to avoid sending it to intermediate contracts that have made calls
        if (gasPrice > 0) {
            handleTxPayment(startGas, dataGas, gasPrice, gasToken, refundReceiver);
        }
    }

    function processMeta(
        bytes memory meta
    )
    internal
    view
    returns (uint256 conversionRate, uint256[4] memory outMeta)
    {
        require(meta.length == 160, "INVALID_DATA: META_LENGTH");  //5 slots

        uint256 oracle; //slot1
        uint256 period; //slot2
        uint256 offChainID; //slot3
        uint256 startDate; //slot4
        uint256 expire; //slot5

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            oracle := mload(add(meta, add(0x20, 0)))
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            period := mload(add(meta, add(0x20, 32)))
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            offChainID := mload(add(meta, add(0x20, 64)))
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            startDate := mload(add(meta, add(0x20, 96)))
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            expire := mload(add(meta, add(0x20, 128)))
        }

        if (oracle != uint256(0)) {
            bytes32 rate = OracleRegistry(oracleRegistry).read(oracle);
            conversionRate = uint256(rate);
        } else {
            conversionRate = uint256(0);
        }

        return (conversionRate, [period, offChainID, startDate, expire]);
    }

    function paySubscription(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        bytes32 subHash,
        bytes memory meta
    )
    internal
    returns (bool success)
    {
        uint256 conversionRate;
        uint256[4] memory processedMetaData;

        (conversionRate, processedMetaData) = processMeta(meta);

        processSub(subHash, processedMetaData);

        //Oracle Registry address data is in slot1
        if (conversionRate != uint256(0)) {

            require(value > 1.00 ether, "INVALID_FORMAT: PRICE_FEED");

            uint256 payment = value.wdiv(conversionRate);

            success = manager.execTransactionFromModule(to, payment, "0x", operation);

            emit DynamicPayment(conversionRate, payment);
        } else {
            success = manager.execTransactionFromModule(to, value, data, operation);
        }
    }

    function handleTxPayment(
        uint256 gasUsed,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver
    )
    internal
    {
        uint256 amount = gasUsed.sub(gasleft()).add(dataGas).mul(gasPrice);
        // solium-disable-next-line security/no-tx-origin
        address receiver = refundReceiver == address(0) ? tx.origin : refundReceiver;
        if (gasToken == address(0)) {
            // solium-disable-next-line security/no-send
            require(manager.execTransactionFromModule(receiver, amount, "0x", Enum.Operation.Call), "FAILED_EXEC: PAYMENT_ETH");
        } else {
            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", receiver, amount);
            // solium-disable-next-line security/no-inline-assembly
            require(manager.execTransactionFromModule(gasToken, 0, data, Enum.Operation.Call), "FAILED_EXEC: PAYMENT_GASTOKEN");
        }
    }


    function checkHash(
        bytes32 transactionHash,
        bytes memory signatures
    )
    internal
    view
    returns (bool valid)
    {
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint256 i;
        uint256 threshold = OwnerManager(address(manager)).getThreshold();
        // Validate threshold is reached.
        valid = false;
        for (i = 0; i < threshold; i++) {
            currentOwner = recoverKey(transactionHash, signatures, i);
            require(OwnerManager(address(manager)).isOwner(currentOwner), "INVALID_DATA: SIGNATURE_NOT_OWNER");
            require(currentOwner > lastOwner, "INVALID_DATA: SIGNATURE_OUT_ORDER");
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
        bytes memory signatures
    )
    public
    view
    returns (bool isValid)
    {

        Meta storage sub = subscriptions[subscriptionHash];

        if(sub.status == GEnum.SubscriptionStatus.TRIAL && sub.nextWithdraw <= now) {
            return true;
        } else if (sub.status == GEnum.SubscriptionStatus.VALID) {
            return true;
        } else if (sub.status == GEnum.SubscriptionStatus.EXPIRED) {
            require(sub.expires != 0, "INVALID_STATE: SUB_EXPIRES");
            return (now <= sub.expires);
        } else if (sub.status == GEnum.SubscriptionStatus.INIT) {
            return checkHash(subscriptionHash, signatures);
        }
        return false;
    }

    function cancelSubscription(
        bytes32 subHash
    )
    authorized
    public
    returns (bool) {
        Meta storage sub = subscriptions[subHash];
        require((sub.status != GEnum.SubscriptionStatus.CANCELLED) && (sub.status != GEnum.SubscriptionStatus.INIT) && (sub.status != GEnum.SubscriptionStatus.EXPIRED), "INVALID_STATE: SUB_STATUS");

        sub.status = GEnum.SubscriptionStatus.CANCELLED;
        emit SubscriptionCancelled(subHash);
        return true;
    }

    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that submitted the transaction.
    ///      Note: The fees are always transferred, even if the user transaction fails.
    /// @return bool hash of on sub to revoke or cancel
    function cancelSubscription(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes memory meta,
        bytes memory signatures
    )
    public
    returns (bool)
    {
        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation,
            safeTxGas, dataGas, gasPrice, gasToken, refundReceiver,
            meta
        );
        Meta storage sub = subscriptions[keccak256(subHashData)];

        require(sub.status != GEnum.SubscriptionStatus.CANCELLED, "INVALID_STATE: SUB_STATUS");
        require(checkHash(keccak256(subHashData), signatures), "INVALID_DATA: SIGNATURES_INVALID");

        sub.status = GEnum.SubscriptionStatus.CANCELLED;

        emit SubscriptionCancelled(keccak256(subHashData));
        return true;
    }

    /// @dev used to help mitigate stack issues
    /// @return bool
    function processSub(
        bytes32 subHash,
        uint256[4] memory pmeta
    )
    internal
    {
        uint256 period = pmeta[0];
        uint256 offChainID = pmeta[1];
        uint256 startDate = pmeta[2];
        uint256 expires = pmeta[3];

        uint256 withdrawHolder;
        Meta storage sub = subscriptions[subHash];

        require((sub.status != GEnum.SubscriptionStatus.EXPIRED && sub.status != GEnum.SubscriptionStatus.CANCELLED), "INVALID_STATE: SUB_STATUS");


        if (sub.status == GEnum.SubscriptionStatus.INIT) {

            if (expires != 0) {
                require(expires > now, "INVALID_DATA: SUB_EXPIRES");
                sub.expires = expires;
            }

            if (offChainID != 0) {
                sub.offChainID = offChainID;
            }

            if (startDate != 0) {
                require(startDate > now, "INVALID_DATA: SUB_STARTDATE");
                sub.nextWithdraw = startDate;
                sub.status = GEnum.SubscriptionStatus.TRIAL;
            } else {
                sub.nextWithdraw = now;
                sub.status = GEnum.SubscriptionStatus.VALID;
            }
        } else if (sub.status == GEnum.SubscriptionStatus.TRIAL) {
            sub.nextWithdraw = now;
        }

        require((sub.status == GEnum.SubscriptionStatus.VALID || sub.status == GEnum.SubscriptionStatus.TRIAL), "INVALID_STATE: SUB_STATUS");
        require(now >= sub.nextWithdraw, "INVALID_STATE: SUB_NEXTWITHDRAW");

        if (period == uint(GEnum.Period.DAY)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 1);
        } else if (period == uint(GEnum.Period.WEEK)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 7);
        } else if (period == uint(GEnum.Period.MONTH)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(sub.nextWithdraw, 1);
        } else {
            revert(string(abi.encodePacked(period)));
        }

        //if a subscription is expiring and its next withdraw timeline is beyond hte time of the expiration
        //modify the status
        if (sub.expires != 0 && withdrawHolder > sub.expires) {
            sub.status = GEnum.SubscriptionStatus.EXPIRED;
            sub.nextWithdraw = 0;
        } else {
            sub.nextWithdraw = withdrawHolder;
        }


        emit SubscriptionProcessed(subHash);
    }


    function getSubscriptionMetaBytes(
        uint256 oracle,
        uint256 period,
        uint256 offChainID,
        uint256 startDate,
        uint256 expires
    )
    public
    pure
    returns (bytes memory)
    {
        return abi.encodePacked(oracle, period, offChainID, startDate, expires);
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
    /// @param meta bytes refundReceiver / period / offChainID / expires
    /// @return Subscription hash.
    function getSubscriptionHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes memory meta
    )
    public
    view
    returns (bytes32)
    {
        return keccak256(encodeSubscriptionData(to, value, data, operation, safeTxGas, dataGas, gasPrice, gasToken, refundReceiver, meta));
    }


    /// @dev Returns the bytes that are hashed to be signed by owners.
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @param operation Operation type.
    /// @param safeTxGas Fas that should be used for the safe transaction.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param meta bytes packed data(refund address, period, offChainID, expires
    /// @return Subscription hash bytes.
    function encodeSubscriptionData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes memory meta
    )
    public
    view
    returns (bytes memory)
    {
        bytes32 safeSubTxHash = keccak256(
            abi.encode(SAFE_SUB_TX_TYPEHASH, to, value, keccak256(data), operation, safeTxGas, dataGas, gasPrice, gasToken, refundReceiver, keccak256(meta))
        );
        return abi.encodePacked(byte(0x19), byte(0x01), domainSeparator, safeSubTxHash);
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
    /// @param meta meta data of subscription agreement
    /// @return Estimate without refunds and overhead fees (base transaction and payload data gas costs).
    function requiredTxGas(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        bytes memory meta
    )
    public
    authorized
    returns (uint256)
    {
        uint256 startGas = gasleft();
        // We don't provide an error message here, as we use it to return the estimate
        // solium-disable-next-line error-reason

        (uint256 conversionRate, uint256[4] memory pMeta) = processMeta(meta);

        require(manager.execTransactionFromModule(to, value, data, operation), "INVALID_EXEC");
        uint256 requiredGas = startGas.sub(gasleft());
        // Convert response to string and return via error message
        revert(string(abi.encodePacked(requiredGas)));

    }
}
