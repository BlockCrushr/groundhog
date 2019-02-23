pragma solidity ^0.5.0;

import "../base/Module.sol";
import "../base/OwnerManager.sol";
import "../common/GEnum.sol";
import "../common/Enum.sol";
import "../common/SignatureDecoder.sol";
import "../external/BokkyPooBahsDateTimeLibrary.sol";
import "../external/Math.sol";
import "../interfaces/OracleRegistryI.sol";

/// @title SubscriptionModule - A module with support for Subscription Payments
/// @author Andrew Redden - <andrew@groundhog.network>
contract SubscriptionModule is Module, SignatureDecoder {


    using BokkyPooBahsDateTimeLibrary for uint256;
    using DSMath for uint256;

    string public constant NAME = "Groundhog";
    string public constant VERSION = "0.1.0";

    bytes32 public domainSeparator;
    address public oracleRegistry;

    //keccak256(
    //    "EIP712Domain(address verifyingContract)"
    //);
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;

    //keccak256(
    //  "EIP1337Execute(address to,uint256 value,bytes data,uint8 period,uint256 startDate,uint256 endDate,uint256 uniqId)"
    //)
    bytes32 public constant EIP1337_TYPEHASH = 0xfb712ff729dee2cfef270710d9358c6b90f95803526927d0f046a957b02071ae;

    //    //keccak256(
    //    //  "EIP1337Execute(address to,uint256 value,bytes data,uint8 period,uint8 rate,uint256 startDate,uint256 endDate,uint256 uniqId)"
    //    //)
    //    bytes32 public constant EIP1337_TYPEHASH = 0x42d388c264cfbbed274909b3cf362a96c5cf9b2cd6733165cb9a8bb92b532098;

    //keccak256(
    //  "EIP1337Action(bytes32 subscriptionHash,string action)"
    //)
    bytes32 public constant EIP1337_ACTION_TYPEHASH = 0x98c669e75fc9074217ec4f5c9c90babd89fd441cbf72df46c51dc164302d29a6;

    mapping(bytes32 => Meta) public subscriptions;

    struct Meta {
        GEnum.SubscriptionStatus status;
        uint256 nextWithdraw;
        uint256 endDate;
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
    /// @param period uint256
    /// @param uniqId uint256
    /// @param startDate uint256
    /// @param endDate uint256
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint2568 v})
    /// @return success boolean value of execution
    function execSubscription(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId,
        bytes memory signatures
    )
    public
    returns
    (
        bool paid
    )
    {

        bytes memory subHashData = encodeSubscriptionData(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            uniqId
        );

        require(
            _checkHash(
                keccak256(subHashData),
                signatures
            ),
            "SubscriptionModule::execSubscription: INVALID_DATA: SIGNATURES"
        );

        paid = _paySubscription(
            to,
            value,
            data,
            keccak256(subHashData),
            period,
            startDate,
            endDate,
            uniqId
        );
    }


    /// @dev internal method to execution the actual payment
    function _paySubscription(
        address to,
        uint256 value,
        bytes memory data,
        bytes32 subscriptionHash,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId
    )
    internal
    returns (bool processPayment)
    {


        processPayment = _processSub(
            subscriptionHash,
            period,
            startDate,
            endDate,
            uniqId
        );

        if (processPayment) {

            uint256 conversionRate;
            if (value != 0 && (data.length == 32)) {//find a better type identifier to show these, first x bytes are something
                //if its 32 exactly, its likely just the one uint256, which means this is not a function call

                uint256 oracleFeed = abi.decode(
                    data, (uint)
                );

                bytes32 rate = OracleRegistryI(oracleRegistry).read(
                    oracleFeed
                );

                conversionRate = uint256(rate);

                require(conversionRate != uint(0));
                data = "0x";
            }

            if (conversionRate != uint256(0)) {

                //when in priceFeed format, price feeds are denominated in Ether but converted to the feed pairing
                //ETHUSD, WBTC/USD
                require(
                    value > 1.00 ether,
                    "SubscriptionModule::_paySubscription: INVALID_FORMAT: DYNAMIC_PRICE_FORMAT"
                );

                uint256 payment = value.wdiv(
                    conversionRate
                );

                emit OraclizedDenomination(
                    subscriptionHash,
                    value,
                    conversionRate,
                    payment
                );

                value = payment;
            }

            require(
                manager.execTransactionFromModule(to, value, data, Enum.Operation.Call),
                "SubscriptionModule::_paySubscription: INVALID_EXEC: PAY_SUB"
            );
        }
    }



    /// @dev hash check function, to verify that owners have signed the incoming signature
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

    //cancel subscription as a gnosis safe txn
    function cancelSubscriptionAsManager(
        bytes32 subscriptionHash
    )
    authorized
    public
    returns (bool success) {

        success = _cancelSubscription(subscriptionHash);
    }

    /// @dev cancel the subscription as the recipient of the subscription, in cases where a merchant wants to
    /// cancel and prevent further payment
    function cancelSubscriptionAsRecipient(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId,
        bytes memory signatures
    )
    public
    returns (bool cancelled) {

        bytes memory subHashData = encodeSubscriptionData(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            uniqId
        );

        require(
            _checkHash(keccak256(subHashData), signatures),
            "SubscriptionModule::cancelSubscriptionAsRecipient: INVALID_DATA: SIGNATURES"
        );

        address recipient = to;
//        if no value, assume its an ERC20 token, remove the to argument from the data
        if (value == uint(0)) {

            // solium-disable-next-line security/no-inline-assembly
            assembly {
                recipient := div(mload(add(add(data, 0x20), 16)), 0x1000000000000000000000000)
            }
        }

        require(msg.sender == recipient, "SubscriptionModule::isRecipient: MSG_SENDER_NOT_RECIPIENT");

        cancelled = _cancelSubscription(keccak256(subHashData));

    }


    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that
    /// submitted the transaction.
    /// @return bool hash of on sub to revoke or cancel
    function cancelSubscription(
        bytes32 subscriptionHash,
        bytes memory signatures
    )
    public
    returns (bool cancelled)
    {

        bytes32 cancelHash = getSubscriptionActionHash(subscriptionHash, "cancel");

        require(
            _checkHash(cancelHash, signatures),
            "SubscriptionModule::cancelSubscription: INVALID_DATA: SIGNATURES_INVALID"
        );

        cancelled = _cancelSubscription(subscriptionHash);

    }


    /// @dev the internal function that cancels the subscription
    function _cancelSubscription(
        bytes32 subscriptionHash
    )
    internal
    returns (bool cancelled)
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

        cancelled = true;
    }

    /// @dev used to help mitigate stack issues
    /// @return bool
    function _processSub(
        bytes32 subscriptionHash,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId
    )
    internal
    returns (bool processPayment)
    {
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

                //early exit to let trial period start
                processPayment = false;
                return processPayment;
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

        if (
            period == uint256(GEnum.Period.MINUTE)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMinutes(sub.nextWithdraw, 1);
        } else if (
            period == uint256(GEnum.Period.HOUR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addHours(sub.nextWithdraw, 1);
        } else if (
            period == uint256(GEnum.Period.DAY)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 1);
        } else if (
            period == uint256(GEnum.Period.WEEK)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 7);
        } else if (
            period == uint256(GEnum.Period.BI_WEEKLY)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(sub.nextWithdraw, 14);
        } else if (
            period == uint256(GEnum.Period.MONTH)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(sub.nextWithdraw, 1);
        } else if (
            period == uint256(GEnum.Period.THREE_MONTH)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(sub.nextWithdraw, 3);

        } else if (
            period == uint256(GEnum.Period.SIX_MONTH)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(sub.nextWithdraw, 6);

        } else if (
            period == uint256(GEnum.Period.YEAR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(sub.nextWithdraw, 1);
        } else if (
            period == uint256(GEnum.Period.TWO_YEAR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(sub.nextWithdraw, 2);

        } else if (
            period == uint256(GEnum.Period.THREE_YEAR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(sub.nextWithdraw, 3);

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
        processPayment = true;
    }

    /// @dev Returns hash to be signed by owners.
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @return Subscription hash.
    function getSubscriptionHash(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId
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
                period,
                startDate,
                endDate,
                uniqId
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

        bytes32 eip1337ActionHash = keccak256(
            abi.encode(
                EIP1337_ACTION_TYPEHASH,
                subscriptionHash,
                keccak256(abi.encodePacked(action))
            )
        );

        return keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                eip1337ActionHash
            )
        );
    }


    /// @dev Returns the bytes that are hashed to be signed by owners.
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @return Subscription hash bytes.
    function encodeSubscriptionData(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId
    )
    public
    view
    returns (bytes memory)
    {
        bytes32 eip1337TxHash = keccak256(
            abi.encode(
                EIP1337_TYPEHASH,
                to,
                value,
                keccak256(data),
                period,
                startDate,
                endDate,
                uniqId
            )
        );

        return abi.encodePacked(
            byte(0x19),
            byte(0x01),
            domainSeparator,
            eip1337TxHash
        );
    }
}
