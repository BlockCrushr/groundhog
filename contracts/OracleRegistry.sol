pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./DSFeed.sol";

contract OracleRegistry is Ownable {


    address payable private _networkWallet;
    address private _networkExecutor;

    // TODO: set this to 0.005 ETH as WEI, bytes32 encoded0x
    uint256 public baseFee = uint256(0x0000000000000000000000000000000000000000000000000011c37937e08000);

    mapping(address => bool) public isWhitelisted;
    mapping(uint256 => address) public oracles;
    mapping(address => mapping(address => uint256)) public splitterToFee;


    event OracleActivated(address, uint256);

    /// @dev Setup function sets initial storage of contract.
    /// @param _oracles List of whitelisted oracles.
    function setup(
        address[] memory _oracles,
        uint256[] memory _currencyPair,
        address payable[] memory _networkSettings
    )
    public
    onlyOwner
    {
        require(_oracles.length == _currencyPair.length);

        for (uint256 i = 0; i < _oracles.length; i++) {
            addToWhitelist(_oracles[i], _currencyPair[i]);
        }

        require(_networkSettings.length == 2, "OracleResigstry::setup INVALID_DATA: NETWORK_SETTINGS_LENGTH");

        require(_networkWallet == address(0), "OracleResigstry::setup INVALID_STATE: NETWORK_WALLET_SET");

        _networkWallet = _networkSettings[0];

        require(_networkExecutor == address(0), "OracleResigstry::setup INVALID_STATE: NETWORK_EXECUTOR_SET");

        _networkExecutor = _networkSettings[1];
    }

    function read(uint256 currencyPair) public view returns (bytes32) {
        address orl = oracles[currencyPair];
        require(isWhitelisted[orl], "INVALID_DATA: CURRENCY_PAIR");
        return DSFeed(orl).read();
    }

    /// @dev Allows to add destination to whitelist. This can only be done via a Safe transaction.
    /// @param oracle Destination address.
    function addToWhitelist(address oracle, uint256 currencyPair)
    public
    onlyOwner
    {
        require(!isWhitelisted[oracle], "OracleResigstry::addToWhitelist INVALID_STATE: ORACLE_WHITELIST");
        require(oracle != address(0), "OracleResigstry::addToWhitelist INVALID_DATA: ORACLE_ADDRESS");
        require(currencyPair != uint256(0), "OracleResigstry::addToWhitelist INVALID_DATA: ORACLE_CURRENCY_PAIR");
        oracles[currencyPair] = oracle;
        isWhitelisted[oracle] = true;
        emit OracleActivated(oracle, currencyPair);
    }

    /// @dev Allows to remove destination from whitelist. This can only be done via a Safe transaction.
    /// @param oracle Destination address.
    function removeFromWhitelist(address oracle)
    public
    onlyOwner
    {
        require(isWhitelisted[oracle], "Address is not whitelisted");
        isWhitelisted[oracle] = false;
    }

    function getNetworkExecutor()
    public
    returns (address) {
        return _networkExecutor;
    }

    function getNetworkWallet()
    public
    returns (address payable) {
        return _networkWallet;
    }

    function getNetworkFee(address asset)
    public
    returns (uint256) {
        //return splitterToFee[msg.sender][asset];
        return baseFee;
    }

}
