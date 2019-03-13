pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

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

interface MMInterface {
    function split(
        address tokenAddress
    )
    external returns (bool);
}


interface SM {

    function isValid(
        bytes32 hash,
        bytes calldata signatures
    ) external view returns (bool);

    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
        bytes calldata signatures
    ) external returns (bool);

    function cancelAsRecipient(
        address to,
        uint256 value,
        bytes calldata data,
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
        bytes calldata signatures
    ) external returns (bool);

    function getHash(
        address to,
        uint256 value,
        bytes calldata data,
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique
    ) external returns (bytes32);
}

contract BulkExecutor is Ownable {

    event SuccessSplit(
        address indexed subscriptionModule,
        address indexed merchantModule,
        address indexed asset
    );

    event NoPayment(
        address indexed subscriptionModule,
        address indexed merchantModule,
        address indexed asset
    );

    function bulkExecute(
        address[] memory customers,
        address payable[] memory to,
        uint256[] memory value,
        bytes[] memory data,
        GEnum.Period[] memory period,
        uint256[] memory startDate,
        uint256[] memory endDate,
        uint256[] memory unique,
        bytes[] memory sig
    )
    public
    returns (
        uint256 i
    )
    {
        i = 0;

        bool[] memory toSplit = new bool[](customers.length);
        address[2] memory holder;

        while (i < customers.length) {

            toSplit[i] = false;
            require(customers[i] >= holder[0], "SORT CUSTOMERS ASC");

            if (customers[i] > holder[0]) {
                holder[1] = address(0x1);
                //SENTINEL_RESET
            }
            if (SM(customers[i]).execute(
                    to[i],
                    value[i],
                    data[i],
                    period[i],
                    startDate[i],
                    endDate[i],
                    unique[i],
                    sig[i]
                )
            ) {
                if (to[i] != holder[1]) {
                    toSplit[i] = true;
                }
            }

            holder[1] = to[i];
            i++;

        }

        i = 0;

        for (i = 0; i < toSplit.length; i++) {

            if (toSplit[i]) {

                address payable merchant = to[i];
                address asset = address(0);

                //value of 0 means its paying via some smart contract(erc20 token, etc)
                if (value[i] == uint(0)) {

                    bytes memory _data = data[i];
                    // extract the merchant from the data payload

                    // solium-disable-next-line security/no-inline-assembly
                    assembly {
                        merchant := div(mload(add(add(_data, 0x20), 16)), 0x1000000000000000000000000)
                    }

                    //smart contract for the token
                    asset = to[i];

                }

                if (MMInterface(merchant).split(asset)) {
                    emit SuccessSplit(customers[i], merchant, asset);
                } else {
                    emit NoPayment(customers[i], merchant, asset);
                }
            }
        }
    }

    /// @dev fail safe to execute the split, great for non workflow txns that place ether or tokens at merchant contract
    function manualSplit(
        address merchant,
        address asset
    )
    public
    returns (
        bool success
    ) {
        return MMInterface(merchant).split(asset);
    }
}
