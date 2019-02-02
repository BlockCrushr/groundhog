pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./common/Enum.sol";
import "./modules/SubscriptionModule.sol";
import "./modules/PaymentSplitter.sol";

contract BulkExecutor is Ownable {


    event SuccessSplit();
    event LogUint(uint, string);
    event LogAddress(address, string);
    event LogBytes32(bytes32, string);
    event LogBytes(bytes, string);
    event LogUint8(Enum.Operation, string);

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

                        //erc20 token check at to[i];
                        //decode function signature so we can leverage the arguments
                        (bytes4 selector, address payable splitter, uint payment) = abi.decode(data[i], (bytes4, address, uint));

                        PaymentSplitter(splitter).split(to[i]);

                    } else {
                        PaymentSplitter(address(to[i])).split(address(0));
                    }

                }
            i++;
        }
    }
}
