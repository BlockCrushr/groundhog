pragma solidity ^0.5.0;

import "../../common/GEnum.sol";

interface SM {

    function isValid(
        bytes32 hash,
        bytes calldata signatures
    ) external view returns (bool);

    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
        bytes calldata signatures
    ) external returns (bool);

    function cancelAsRecipient(
        address to,
        uint256 value,
        bytes calldata data,
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique,
        bytes calldata signatures
    ) external returns (bool);

    function getHash(
        address to,
        uint256 value,
        bytes calldata data,
        GEnum.Period period,
        uint256 startDate,
        uint256 endDate,
        uint256 unique
    ) external returns (bytes32);
}
