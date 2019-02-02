pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./common/Enum.sol";
import "./modules/SubscriptionModule.sol";
import "./modules/PaymentSplitter.sol";

contract BulkExecutor is Ownable {


    event SuccessSplit();

    function execute(
        address[] memory customers,
        address payable[] memory to,
        uint256[] memory value,
        bytes[] memory data,
        Enum.Operation[] memory operation,
        uint256[][] memory gasInfo, //0 txgas 1dataGas 2 gasPrice
        address[] memory gasToken,
        address payable[] memory refundReceiver,
        bytes[][] memory metaSig
    )
    public
    returns (
        uint256 i
    )
    {
        i = 0;
        address transferDecode = address(this);
        while (i < customers.length) {

            if (SubscriptionModule(customers[i]).execSubscription(
                    to[i],
                    value[i],
                    data[i],
                    operation[i],
                    gasInfo[i][0], //txgas
                    gasInfo[i][1], //datagas
                    gasInfo[i][2], //gasPrice
                    gasToken[i],
                    refundReceiver[i],
                    metaSig[i][0], //meta
                    metaSig[i][1]  //sigs
                )
            ) {

                if (value[i] == uint(0)) {

                    address payable splitter;
                    bytes memory dataLocal = data[i];
                    // solium-disable-next-line security/no-inline-assembly
                    assembly {
                        splitter := div(mload(add(add(dataLocal, 0x20), 16)), 0x1000000000000000000000000)
                    }

                    if ((PaymentSplitter(splitter).split(to[i]))) {
                        emit SuccessSplit();
                    }

                } else {
                    if (PaymentSplitter(address(to[i])).split(address(0))) {
                        emit SuccessSplit();
                    }
                }
            }
            i++;
        }
    }
}