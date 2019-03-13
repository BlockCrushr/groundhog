pragma solidity ^0.5.0;

import "../base/Module.sol";
import "../base/OwnerManager.sol";
import "../common/GEnum.sol";
import "../common/SignatureDecoder.sol";
import "../external/BokkyPooBahsDateTimeLibrary.sol";
import "../external/Math.sol";
import "../interfaces/OracleRegistryI.sol";

/// @title SubscriptionModule - A module with support for Subscription Payments
/// @author Andrew Redden - <andrew@groundhog.network>
contract SubscriptionModule is Module, SignatureDecoder {


    using BokkyPooBahsDateTimeLibrary for uint256;
    using DSMath for uint256;

    string public constant NAME = "SubscriptionModule";
    string public constant VERSION = "0.1.0";

    bytes32 public domainSeparator;
    address public oracleRegistry;

    //keccak256(
    //    "EIP712Domain(address verifyingContract)"
    //);
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;

    //keccak256(
    //  "EIP1337Execute(address to,uint256 value,bytes data,uint8 period,uint256 startDate,uint256 endDate,uint256 unique)"
    //)
    bytes32 public constant EIP1337_TYPEHASH = 0x5b2427a6a143d63fc84d73a2ad07e5058a013b12e476c04a97c43b86bbb2392b;

    //keccak256(
    //  "EIP1337Action(bytes32 hash,string action)"
    //)
    bytes32 public constant EIP1337_ACTION_TYPEHASH = 0x1c6d00adc347592e646f0e48a431169e705ca19f86f9a3849e50e8557a510051;

    mapping(bytes32 => Meta) public subscriptions;

    struct Meta {
        GEnum.Status status;
        uint256 nextWithdraw;
        uint256 endDate;
        uint256 startDate;
    }

    event NextPayment(
        bytes32 indexed hash,
        uint256 nextWithdraw
    );

    event OraclizedDenomination(
        bytes32 indexed hash,
        uint256 indexed dynPriceFormat,
        uint256 conversionRate,
        uint256 paymentTotal
    );
    event StatusChanged(
        bytes32 indexed hash,
        GEnum.Status indexed prev,
        GEnum.Status indexed next
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
    /// @param unique uint256
    /// @param startDate uint256
    /// @param endDate uint256
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint256 v})
    /// @return success boolean value of execution
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
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
            unique
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
            unique
        );
    }

    /// @dev internal method to execution the actual payment
    function _paySubscription(
        address to,
        uint256 value,
        bytes memory data,
        bytes32 hash,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique
    )
    internal
    returns (bool processPayment)
    {


        processPayment = _process(
            hash,
            period,
            startDate,
            endDate,
            unique
        );

        if (processPayment) {

            if (value != 0 && (data.length == 32)) {
                //find a better type identifier to show these, first x bytes are something
                //if its 32 exactly, its likely just the one uint256, which means this is not a function call
                uint256 conversionRate;

                uint256 oracleFeed = abi.decode(
                    data, (uint)
                );

                (bytes32 rate, address payable asset) = OracleRegistryI(oracleRegistry).read(oracleFeed);

                conversionRate = uint256(rate);

                require(
                    conversionRate != uint(0),
                    "SubscriptionModule::_paySubscription: INVALID_FORMAT: CONVERSION_RATE"
                );


                //when in priceFeed format, price feeds are denominated in Ether but converted to the feed pairing
                //ETH/USD, WBTC/USD
                require(
                    value >= 0.50 ether,
                    "SubscriptionModule::_paySubscription: INVALID_FORMAT: DYNAMIC_PRICE_FORMAT"
                );

                uint256 payment = value.wdiv(
                    conversionRate
                );

                emit OraclizedDenomination(
                    hash,
                    value,
                    conversionRate,
                    payment
                );

                if (asset != address(0)) {

                    //token receipient currently stored in the to field
                    data = abi.encodeWithSignature(
                        'transfer(address, uint256)',
                        to,
                        payment
                    );

                    //since its a token the transaction to field needs to be the asset smart contract
                    //value is now 0 as well
                    to = asset;
                    value = 0;
                } else {
                    data = "0x"; //ether payment is just 0x for data
                    value = payment; //set value to the converted payment
                }

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
                signatures,
                i
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
    /// @param hash bytes32 hash of on chain sub
    /// @return bool valid returns the validity of the subscription
    function isValid(
        bytes32 hash,
        bytes memory signatures
    )
    public
    view
    returns (bool valid)
    {

        Meta storage sub = subscriptions[hash];

        //exit early if we can
        if (sub.status == GEnum.Status.INIT) {
            return _checkHash(
                hash,
                signatures
            );
        }

        if (sub.status == GEnum.Status.EXPIRED || sub.status == GEnum.Status.CANCELLED) {

            require(
                sub.endDate != 0,
                "SubscriptionModule::isValid: INVALID_STATE: SUB_STATUS"
            );

            valid = (now <= sub.endDate);
        } else if (
            (sub.status == GEnum.Status.TRIAL && sub.nextWithdraw <= now)
            ||
            (sub.status == GEnum.Status.VALID)
        ) {
            valid = true;
        } else {
            valid = false;
        }
    }

    //cancel subscription as a gnosis safe txn
    function cancelAsManager(
        bytes32 hash
    )
    authorized
    public
    returns (bool success) {

        success = _cancel(hash);
    }

    /// @dev cancel the subscription as the recipient of the subscription, in cases where a merchant wants to
    /// cancel and prevent further payment
    function cancelAsRecipient(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
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
            unique
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

        cancelled = _cancel(keccak256(subHashData));

    }


    /// @dev Allows to execute a Safe transaction confirmed by required number of owners and then pays the account that
    /// submitted the transaction.
    /// @return bool hash of on sub to revoke or cancel
    function cancel(
        bytes32 hash,
        bytes memory signatures
    )
    public
    returns (bool cancelled)
    {

        bytes32 cancelhash = getActionHash(hash, "cancel");

        require(
            _checkHash(cancelhash, signatures),
            "SubscriptionModule::cancelSubscription: INVALID_DATA: SIGNATURES_INVALID"
        );

        cancelled = _cancel(hash);

    }


    /// @dev the internal function that cancels the subscription
    function _cancel(
        bytes32 hash
    )
    internal
    returns (bool cancelled)
    {

        Meta storage sub = subscriptions[hash];


        require(
            (sub.status != GEnum.Status.CANCELLED && sub.status != GEnum.Status.EXPIRED),
            "SubscriptionModule::_cancel: INVALID_STATE: SUB_STATUS"
        );

        emit StatusChanged(
            hash,
            sub.status,
            GEnum.Status.CANCELLED
        );

        sub.status = GEnum.Status.CANCELLED;

        if (sub.status != GEnum.Status.INIT) {
            sub.endDate = sub.nextWithdraw;
        }

        sub.nextWithdraw = 0;

        cancelled = true;
    }

    /// @dev used to help mitigate stack issues
    /// @return bool
    function _process(
        bytes32 hash,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique
    )
    internal
    returns (bool processPayment)
    {
        uint256 withdrawHolder;
        Meta storage sub = subscriptions[hash];

        require(
            (sub.status != GEnum.Status.EXPIRED && sub.status != GEnum.Status.CANCELLED),
            "SubscriptionModule::_process: INVALID_STATE: SUB_STATUS"
        );


        if (sub.status == GEnum.Status.INIT) {

            if (endDate != 0) {

                require(
                    endDate >= now,
                    "SubscriptionModule::_process: INVALID_DATA: SUB_END_DATE"
                );
                sub.endDate = endDate;
            }

            if (startDate != 0 && startDate >= now) {

                sub.nextWithdraw = startDate;
                sub.startDate = startDate;
                sub.status = GEnum.Status.TRIAL;

                emit StatusChanged(
                    hash,
                    GEnum.Status.INIT,
                    GEnum.Status.TRIAL
                );
                //emit here because of early method exit after trial setup
                emit NextPayment(
                    hash,
                    sub.nextWithdraw
                );

                //early exit to let trial period start
                processPayment = false;
                return processPayment;

            } else {

                sub.nextWithdraw = now;
                sub.startDate = now;
                sub.status = GEnum.Status.VALID;
                emit StatusChanged(
                    hash,
                    GEnum.Status.INIT,
                    GEnum.Status.VALID
                );
            }

        } else if (sub.status == GEnum.Status.TRIAL) {

            require(
                now >= startDate,
                "SubscriptionModule::_process: INVALID_STATE: SUB_START_DATE"
            );
            //prevents drift from a txn being included late by setting it to the startDate
            //only way into trial is from INIT with a startDate greater than the time of inclusion, otherwise its valid
            sub.nextWithdraw = startDate;
            sub.status = GEnum.Status.VALID;

            emit StatusChanged(
                hash,
                GEnum.Status.TRIAL,
                GEnum.Status.VALID
            );
        }

        require(
            sub.status == GEnum.Status.VALID,
            "SubscriptionModule::_process: INVALID_STATE: SUB_STATUS"
        );

        require(
            now >= sub.nextWithdraw && sub.nextWithdraw != 0,
            "SubscriptionModule::_process: INVALID_STATE: SUB_NEXT_WITHDRAW"
        );

        if (
            period == uint8(GEnum.Period.DAY)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(
                sub.nextWithdraw, 1
            );
        } else if (
            period == uint8(GEnum.Period.WEEK)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(
                sub.nextWithdraw, 7
            );
        } else if (
            period == uint8(GEnum.Period.BI_WEEKLY)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addDays(
                sub.nextWithdraw, 14
            );
        } else if (
            period == uint8(GEnum.Period.MONTH)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(
                sub.nextWithdraw, 1
            );
        } else if (
            period == uint8(GEnum.Period.THREE_MONTH)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(
                sub.nextWithdraw, 3
            );
        } else if (
            period == uint8(GEnum.Period.SIX_MONTH)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addMonths(
                sub.nextWithdraw, 6
            );
        } else if (
            period == uint8(GEnum.Period.YEAR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(
                sub.nextWithdraw, 1
            );
        } else if (
            period == uint8(GEnum.Period.TWO_YEAR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(
                sub.nextWithdraw, 2
            );
        } else if (
            period == uint8(GEnum.Period.THREE_YEAR)
        ) {
            withdrawHolder = BokkyPooBahsDateTimeLibrary.addYears(
                sub.nextWithdraw, 3
            );
        } else {
            revert(
                "SubscriptionModule::_process: INVALID_DATA: PERIOD"
            );
        }

        //if a subscription is expiring and its next withdraw timeline is beyond the time of the expiration
        if (sub.endDate != 0 && withdrawHolder >= sub.endDate) {

            sub.nextWithdraw = 0;
            emit StatusChanged(
                hash,
                sub.status,
                GEnum.Status.EXPIRED
            );
            sub.status = GEnum.Status.EXPIRED;
        } else {
            sub.nextWithdraw = withdrawHolder;
        }

        emit NextPayment(
            hash,
            sub.nextWithdraw
        );
        processPayment = true;
    }

    /// @dev Returns hash to be signed by owners.
    /// @param to Destination address.
    /// @return Subscription hash.
    function getHash(
        address to,
        uint256 value,
        bytes memory data,
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique
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
                unique
            )
        );
    }

    /// @dev Returns hash to be signed by owners for cancelling a subscription
    function getActionHash(
        bytes32 hash,
        string memory action
    )
    public
    view
    returns (bytes32)
    {

        bytes32 eip1337ActionHash = keccak256(
            abi.encode(
                EIP1337_ACTION_TYPEHASH,
                hash,
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
        uint256 unique
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
                unique
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
