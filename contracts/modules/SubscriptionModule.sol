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

    using BokkyPooBahsDateTimeLibrary for uint256;
    using DSMath for uint256;
    string public constant NAME = "Groundhog";
    string public constant VERSION = "0.0.1";

    bytes32 public domainSeparator;
    address public oracleRegistry;

    //keccak256(
    //    "EIP712Domain(address verifyingContract)"
    //);
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;

    //keccak256(
    //  "SafeSubTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes meta)"
    //)
    bytes32 public constant SAFE_SUB_TX_TYPEHASH = 0x4494907805e3ceba396741b2837174bdf548ec2cbe03f5448d7fa8f6b1aaf98e;

    //keccak256(
    //  "SafeSubCancelTx(bytes32 subscriptionHash,string action)"
    //)
    bytes32 public constant SAFE_SUB_CANCEL_TX_TYPEHASH = 0xef5a0c558cb538697e29722572248a2340a367e5079b08a00b35ef5dd1e66faa;

    mapping(bytes32 => Meta) public subscriptions;

    struct Meta {
        GEnum.SubscriptionStatus status;
        uint256 nextWithdraw;
        uint256 endDate;
        uint256 cycle;
    }

    event NextPayment(
        bytes32 indexed subscriptionHash,
        uint256 nextWithdraw
    );

    event OraclizedDenomination(
        bytes32 indexed subscriptionHash,
        uint256 dynPriceFormat,
        uint256 conversionRate,
        uint256 paymentTotal
    );
    event StatusChanged(
        bytes32 indexed subscriptionHash,
        GEnum.SubscriptionStatus prev,
        GEnum.SubscriptionStatus next
    );

    /// @dev Setup function sets manager
    function setup(
        address _oracleRegistry
    )
    public
    {
        setManager();

        require(
            domainSeparator == 0,
            "SubscriptionModule::setup: INVALID_STATE: DOMAIN_SEPARATOR_SET"
        );

        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                address(this)
            )
        );

        require(
            oracleRegistry == address(0),
            "SubscriptionModule::setup: INVALID_STATE: ORACLE_REGISTRY_SET"
        );

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
    /// @param meta Packed bytes data {address refundReceiver (required}, {uint256 period (required}, {uint256 offChainID (required}, {uint256 endDate (optional}
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint2568 v})
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
    returns
    (
        bool
    )
    {
        uint256 startGas = gasleft();

        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation, // Transaction info
            safeTxGas, dataGas, gasPrice, gasToken,
            refundReceiver, meta
        );

        require(
            gasleft() >= safeTxGas,
            "SubscriptionModule::execSubscription: INVALID_DATA: WALLET_TX_GAS"
        );

        require(
            _checkHash(
                keccak256(subHashData), signatures
            ),
            "SubscriptionModule::execSubscription: INVALID_DATA: SIGNATURES"
        );

        _paySubscription(
            to, value, data, operation,
            keccak256(subHashData), meta
        );

        // We transfer the calculated tx costs to the refundReceiver to avoid sending it to intermediate contracts that have made calls
        if (gasPrice > 0) {
            _handleTxPayment(
                startGas,
                dataGas,
                gasPrice,
                gasToken,
                refundReceiver
            );
        }

        return true;
    }

    function _processMeta(
        bytes memory meta
    )
    internal
    view
    returns (
        uint256 conversionRate,
        uint256[4] memory outMeta
    )
    {
        require(
            meta.length == 160,
            "SubscriptionModule::_processMeta: INVALID_DATA: META_LENGTH"
        );


        (
        uint256 oracle,
        uint256 period,
        uint256 offChainID,
        uint256 startDate,
        uint256 endDate
        ) = abi.decode(
            meta,
            (uint, uint, uint, uint, uint) //5 slots
        );

        if (oracle != uint256(0)) {

            bytes32 rate = OracleRegistry(oracleRegistry).read(oracle);
            conversionRate = uint256(rate);
        } else {
            conversionRate = uint256(0);
        }

        return (conversionRate, [period, offChainID, startDate, endDate]);
    }

    function _paySubscription(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        bytes32 subscriptionHash,
        bytes memory meta
    )
    internal
    {
        uint256 conversionRate;
        uint256[4] memory processedMetaData;

        (conversionRate, processedMetaData) = _processMeta(meta);

        bool processPayment = _processSub(subscriptionHash, processedMetaData);

        if (processPayment) {

            //Oracle Registry address data is in slot1
            if (conversionRate != uint256(0)) {

                //when in priceFeed format, price feeds are denominated in Ether but converted to the feed pairing
                //ETHUSD, WBTC/USD
                require(
                    value > 1.00 ether,
                    "SubscriptionModule::_paySubscription: INVALID_FORMAT: DYNAMIC_PRICE_FORMAT"
                );

                uint256 payment = value.wdiv(conversionRate);

                emit OraclizedDenomination(
                    subscriptionHash,
                    value,
                    conversionRate,
                    payment
                );

                value = payment;
            }

            require(
                manager.execTransactionFromModule(to, value, data, operation),
                "SubscriptionModule::_paySubscription: INVALID_EXEC: PAY_SUB"
            );
        }
    }

    function _handleTxPayment(
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
            require(
                manager.execTransactionFromModule(receiver, amount, "0x", Enum.Operation.Call),
                "SubscriptionModule::_handleTxPayment: FAILED_EXEC: PAYMENT_ETH"
            );
        } else {

            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", receiver, amount);
            // solium-disable-next-line security/no-inline-assembly
            require(
                manager.execTransactionFromModule(gasToken, 0, data, Enum.Operation.Call),
                "SubscriptionModule::_handleTxPayment: FAILED_EXEC: PAYMENT_GAS_TOKEN"
            );
        }
    }

    function _checkHash(
        bytes32 hash,
        bytes memory signatures
    )
    internal
    view
    returns (
        bool valid
    )
    {
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint256 i;
        uint256 threshold = OwnerManager(address(manager)).getThreshold();
        // Validate threshold is reached.
        valid = false;

        for (i = 0; i < threshold; i++) {

            currentOwner = recoverKey(
                hash,
                signatures, i
            );

            require(
                OwnerManager(address(manager)).isOwner(currentOwner),
                "SubscriptionModule::_checkHash: INVALID_DATA: SIGNATURE_NOT_OWNER"
            );

            require(
                currentOwner > lastOwner,
                "SubscriptionModule::_checkHash: INVALID_DATA: SIGNATURE_OUT_ORDER"
            );

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

        //exit early if we can
        if (sub.status == GEnum.SubscriptionStatus.INIT) {
            return _checkHash(
                subscriptionHash,
                signatures
            );
        }

        if (sub.status == GEnum.SubscriptionStatus.EXPIRED || sub.status == GEnum.SubscriptionStatus.CANCELLED) {

            require(
                sub.endDate != 0,
                "SubscriptionModule::isValidSubscription: INVALID_STATE: SUB_STATUS"
            );

            isValid = (now <= sub.endDate);
        } else if (
            (sub.status == GEnum.SubscriptionStatus.TRIAL && sub.nextWithdraw <= now)
            ||
            (sub.status == GEnum.SubscriptionStatus.VALID)
        ) {
            isValid = true;
        } else {
            isValid = false;
        }
    }

    function cancelSubscriptionAsManager(
        bytes32 subscriptionHash
    )
    authorized
    public
    returns (bool) {

        _cancelSubscription(subscriptionHash);

        return true;
    }

    function cancelSubscriptionAsRecipient(
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
    returns (bool) {


        bytes memory subHashData = encodeSubscriptionData(
            to, value, data, operation, // Transaction info
            safeTxGas, dataGas, gasPrice, gasToken,
            refundReceiver, meta
        );

        require(
            _checkHash(keccak256(subHashData), signatures),
            "SubscriptionModule::cancelSubscriptionAsRecipient: INVALID_DATA: SIGNATURES"
        );

        //if no value, assume its an ERC20 token, remove the to argument from the data
        if (value == uint(0)) {

            address recipient;
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                recipient := div(mload(add(add(data, 0x20), 16)), 0x1000000000000000000000000)
            }
            require(msg.sender == recipient, "SubscriptionModule::isRecipient: MSG_SENDER_NOT_RECIPIENT_ERC");
        } else {

            //we are sending ETH, so check the sender matches to argument
            require(msg.sender == to, "SubscriptionModule::isRecipient: MSG_SENDER_NOT_RECIPIENT_ETH");
        }

        _cancelSubscription(keccak256(subHashData));

        return true;
    }


    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that
    /// submitted the transaction.
    /// @return bool hash of on sub to revoke or cancel
    function cancelSubscription(
        bytes32 subscriptionHash,
        bytes memory signatures
    )
    public
    returns (bool)
    {

        bytes32 cancelHash = getSubscriptionActionHash(subscriptionHash, "cancel");

        require(
            _checkHash(cancelHash, signatures),
            "SubscriptionModule::cancelSubscription: INVALID_DATA: SIGNATURES_INVALID"
        );

        _cancelSubscription(subscriptionHash);

        return true;
    }


    function _cancelSubscription(bytes32 subscriptionHash)
    internal
    {

        Meta storage sub = subscriptions[subscriptionHash];


        require(
            (sub.status != GEnum.SubscriptionStatus.CANCELLED && sub.status != GEnum.SubscriptionStatus.EXPIRED),
            "SubscriptionModule::_cancelSubscription: INVALID_STATE: SUB_STATUS"
        );

        emit StatusChanged(
            subscriptionHash,
            sub.status,
            GEnum.SubscriptionStatus.CANCELLED
        );

        sub.status = GEnum.SubscriptionStatus.CANCELLED;

        if (sub.status != GEnum.SubscriptionStatus.INIT) {
            sub.endDate = sub.nextWithdraw;
        }

        sub.nextWithdraw = 0;

        emit NextPayment(
            subscriptionHash,
            sub.nextWithdraw
        );
    }

    /// @dev used to help mitigate stack issues
    /// @return bool
    function _processSub(
        bytes32 subscriptionHash,
        uint256[4] memory processedMeta
    )
    internal
    returns (bool)
    {
        uint256 period = processedMeta[0];
        uint256 offChainID = processedMeta[1];
        uint256 startDate = processedMeta[2];
        uint256 endDate = processedMeta[3];

        uint256 withdrawHolder;
        Meta storage sub = subscriptions[subscriptionHash];

        require(
            (sub.status != GEnum.SubscriptionStatus.EXPIRED && sub.status != GEnum.SubscriptionStatus.CANCELLED),
            "SubscriptionModule::_processSub: INVALID_STATE: SUB_STATUS"
        );


        if (sub.status == GEnum.SubscriptionStatus.INIT) {

            if (endDate != 0) {

                require(
                    endDate >= now,
                    "SubscriptionModule::_processSub: INVALID_DATA: SUB_END_DATE"
                );
                sub.endDate = endDate;
            }

            if (startDate != 0) {

                require(
                    startDate >= now,
                    "SubscriptionModule::_processSub: INVALID_DATA: SUB_START_DATE"
                );
                sub.nextWithdraw = startDate;
                sub.status = GEnum.SubscriptionStatus.TRIAL;

                emit StatusChanged(
                    subscriptionHash,
                    GEnum.SubscriptionStatus.INIT,
                    GEnum.SubscriptionStatus.TRIAL
                );
                //emit here because of early method exit after trial setup
                emit NextPayment(
                    subscriptionHash,
                    sub.nextWithdraw
                );

                return false;
            } else {

                sub.nextWithdraw = now;
                sub.status = GEnum.SubscriptionStatus.VALID;
                emit StatusChanged(
                    subscriptionHash,
                    GEnum.SubscriptionStatus.INIT,
                    GEnum.SubscriptionStatus.VALID
                );
            }

        } else if (sub.status == GEnum.SubscriptionStatus.TRIAL) {

            require(
                now >= startDate,
                "SubscriptionModule::_processSub: INVALID_STATE: SUB_START_DATE"
            );
            sub.nextWithdraw = now;
            sub.status = GEnum.SubscriptionStatus.VALID;

            emit StatusChanged(
                subscriptionHash,
                GEnum.SubscriptionStatus.TRIAL,
                GEnum.SubscriptionStatus.VALID
            );
        }

        require(
            sub.status == GEnum.SubscriptionStatus.VALID,
            "SubscriptionModule::_processSub: INVALID_STATE: SUB_STATUS"
        );

        require(
            now >= sub.nextWithdraw && sub.nextWithdraw != 0,
            "SubscriptionModule::_processSub: INVALID_STATE: SUB_NEXT_WITHDRAW"
        );

        if (period == uint256(GEnum.Period.DAY)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 1);
        } else if (period == uint256(GEnum.Period.WEEK)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 7);
        } else if (period == uint256(GEnum.Period.MONTH)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(sub.nextWithdraw, 1);
        } else if (period == uint256(GEnum.Period.YEAR)) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(sub.nextWithdraw, 1);
        } else {
            revert("SubscriptionModule::_processSub: INVALID_DATA: PERIOD");
        }

        //if a subscription is expiring and its next withdraw timeline is beyond hte time of the expiration
        //modify the status
        if (sub.endDate != 0 && withdrawHolder >= sub.endDate) {

            sub.nextWithdraw = 0;
            emit StatusChanged(
                subscriptionHash,
                sub.status,
                GEnum.SubscriptionStatus.EXPIRED
            );
            sub.status = GEnum.SubscriptionStatus.EXPIRED;
        } else {
            sub.nextWithdraw = withdrawHolder;
        }

        emit NextPayment(
            subscriptionHash,
            sub.nextWithdraw
        );

        return true;
    }


    function getSubscriptionMetaBytes(
        uint256 oracle,
        uint256 period,
        uint256 offChainID,
        uint256 startDate,
        uint256 endDate
    )
    public
    pure
    returns (bytes memory)
    {
        return abi.encodePacked(
            oracle,
            period,
            offChainID,
            startDate,
            endDate
        );
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
    /// @param meta bytes refundReceiver / period / offChainID / endDate
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
        return keccak256(
            encodeSubscriptionData(
                to,
                value,
                data,
                operation,
                safeTxGas,
                dataGas,
                gasPrice,
                gasToken,
                refundReceiver,
                meta
            )
        );
    }

    /// @dev Returns hash to be signed by owners for cancelling a subscription
    function getSubscriptionActionHash(
        bytes32 subscriptionHash,
        string memory action
    )
    public
    view
    returns (bytes32)
    {

        bytes32 safeSubCancelTxHash = keccak256(
            abi.encode(
                SAFE_SUB_CANCEL_TX_TYPEHASH,
                subscriptionHash,
                keccak256(abi.encodePacked(action))
            )
        );

        return keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                safeSubCancelTxHash
            )
        );
    }


    /// @dev Returns the bytes that are hashed to be signed by owners.
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @param operation Operation type.
    /// @param safeTxGas Fas that should be used for the safe transaction.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param meta bytes packed data(refund address, period, offChainID, endDate
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
            abi.encode(
                SAFE_SUB_TX_TYPEHASH,
                to,
                value,
                keccak256(data),
                operation,
                safeTxGas,
                dataGas,
                gasPrice,
                gasToken,
                refundReceiver,
                keccak256(meta)
            )
        );

        return abi.encodePacked(
            byte(0x19),
            byte(0x01),
            domainSeparator,
            safeSubTxHash
        );
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
    returns (uint256)
    {
        require(
            msg.sender == address(this),
            "SubscriptionModule::requiredTxGas: INVALID_DATA: MSG_SENDER"

        );

        uint256 startGas = gasleft();
        // We don't provide an error message here, as we use it to return the estimate
        // solium-disable-next-line error-reason

        (uint256 conversionRate, uint256[4] memory pMeta) = _processMeta(meta);

        //Oracle Registry address data is in slot1
        if (conversionRate != uint256(0)) {

            require(
                value > 1.00 ether,
                "SubscriptionModule::requiredTxGas: INVALID_FORMAT: DYNAMIC_PRICE_FORMAT"
            );

            uint256 payment = value.wdiv(conversionRate);
            value = payment;
        }

        require(
            manager.execTransactionFromModule(to, value, data, operation),
            "SubscriptionModule::requiredTxGas: INVALID_EXEC: SUB_PAY"
        );

        uint256 requiredGas = startGas.sub(gasleft());
        // Convert response to string and return via error message
        revert(string(abi.encodePacked(requiredGas)));

    }
}
