pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./common/Enum.sol";
import "./modules/interfaces/MerchantModule.sol";
import "./modules/interfaces/SubscriptionModule.sol";

contract BulkExecutor is Ownable {


    event SuccessSplit(address merchantModule);

    function execute(
        address[] memory customers,
        address payable[] memory to,
        uint256[] memory value,
        bytes[] memory data,
        uint8[] memory period,
        uint256[] memory startDate,
        uint256[] memory endDate,
        uint256[] memory uniqId,
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
            if (SM(customers[i]).execSubscription(
                    to[i],
                    value[i],
                    data[i],
                    period[i],
                    startDate[i],
                    endDate[i],
                    uniqId[i],
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
        for (uint t = 0; t < toSplit.length; t++) {

            if (toSplit[t]) {

                uint256 _value = value[t];

                address payable merchant;
                address asset;

                //value of 0 means its paying via some smart contract(erc20 token, etc)
                if (_value == uint(0)) {
                    bytes memory _data = data[t];

                    // extract the merchant from the data payload

                    // solium-disable-next-line security/no-inline-assembly
                    assembly {
                        merchant := div(mload(add(add(_data, 0x20), 16)), 0x1000000000000000000000000)
                    }

                    //smart contract for the token
                    asset = to[t];

                } else {

                    merchant = to[t];
                    asset = address(0);
                    //the split is eth, so the _to address is the actual receiving contract
                }

                if (MMInterface(merchant).split(asset)) {
                    emit SuccessSplit(merchant);
                    i++;
                }
            }
        }
    }


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
