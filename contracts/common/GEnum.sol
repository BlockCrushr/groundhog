pragma solidity ^0.5.0;

/// @title GEnum - Collection of enums for subscriptions
/// @author Andrew Redden - <andrew@groundhog.network>
contract GEnum {
    enum SubscriptionStatus {
        INIT,
        TRIAL,
        VALID,
        CANCELLED,
        EXPIRED
    }

    enum Period {
        INIT,
        SECOND,
        MINUTE,
        HOUR,
        DAY,
        WEEK,
        MONTH,
        BI_WEEKLY,
        THREE_MONTH,
        SIX_MONTH,
        YEAR,
        TWO_YEAR,
        THREE_YEAR
    }
}
