pragma solidity 0.4.24;


/// @title Enum - Collection of enums
/// @author Andrew Redden- <andrew@groundhog.network>
contract GEnum {

    enum SubscriptionStatus {
        VALID,
        CANCELLED,
        EXPIRED,
        PAYMENT_FAILED
    }

    enum Period {
        DAY,
        WEEK,
        MONTH
    }
}
