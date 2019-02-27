pragma solidity ^0.5.0;

/// @title GEnum - Collection of enums for subscriptions
/// @author Andrew Redden - <andrew@groundhog.network>
contract GEnum {
    enum Status {
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
        BI_WEEKLY,
        MONTH,
        THREE_MONTH,
        SIX_MONTH,
        YEAR,
        TWO_YEAR,
        THREE_YEAR
    }
}
