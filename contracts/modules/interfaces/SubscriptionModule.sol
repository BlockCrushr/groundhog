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
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata meta,
        bytes calldata signatures) external returns (bool);

    function cancelSubscriptionAsRecipient(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 dataGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata meta,
        bytes calldata signatures) external returns (bool);
}
