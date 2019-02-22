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
        uint256[] memory period,
        uint256[] memory offChainId,
        uint256[] memory startDate,
        uint256[] memory endDate,
        bytes[] memory sig
    )
    public
    returns (
        uint256 i
    )
    {
        i = 0;
        bool[] memory toSplit = new bool[](customers.length);

        while (i < customers.length) {
            if (SM(customers[i]).execSubscription(
                    to[i],
                    value[i],
                    data[i],
                    period[i],
                    offChainId[i],
                    startDate[i],
                    endDate[i],
                    sig[i]
                )
            ) {
                toSplit[i] = true;
            } else {
                toSplit[i] = false;
            }
            i++;

        }

        i = 0;
        for (uint t=0; t < toSplit.length; t++) {

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
}
