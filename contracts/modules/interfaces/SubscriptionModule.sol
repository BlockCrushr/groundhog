pragma solidity ^0.5.0;
import "../../common/Enum.sol";

interface SM {

    function isValidSubscription(
        bytes32 subscriptionHash,
        bytes calldata signatures
    ) external view returns (bool);

    function execSubscription (
        address to,
        uint256 value,
        bytes calldata data,
        uint256 period,
        uint256 offChainId,
        uint256 startDate,
        uint256 endDate,
        bytes calldata signatures) external returns (bool);

    function cancelSubscriptionAsRecipient(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 period,
        uint256 offChainId,
        uint256 startDate,
        uint256 endDate,
        bytes calldata signatures) external returns (bool);
}
