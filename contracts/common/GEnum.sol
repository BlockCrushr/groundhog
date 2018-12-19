pragma solidity ^0.5.0;

/// @title GEnum - Collection of enums for subscriptions
/// @author Andrew Redden - <andrew@groundhog.network>
contract GEnum {
    enum SubscriptionStatus {
        INIT,
        VALID,
        CANCELLED,
        EXPIRED,
        PAYMENT_FAILED
    }

    enum Period {
        INIT,
        DAY,
        WEEK,
        MONTH
    }
}