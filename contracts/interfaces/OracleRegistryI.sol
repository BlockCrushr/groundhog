pragma solidity ^0.5.0;


interface OracleRegistryI {

    function read(
        uint256 currencyPair
    ) external view returns (bytes32);

    function getNetworkExecutor()
    external
    view
    returns (address);

    function getNetworkWallet()
    external
    view
    returns (address payable);

    function getNetworkFee(address asset)
    external
    view
    returns (uint256 fee);
}
