pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./common/GEnum.sol";
import "./modules/interfaces/MerchantModule.sol";
import "./modules/interfaces/SubscriptionModule.sol";

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
