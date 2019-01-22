pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./DSFeed.sol";

contract OracleRegistry is Ownable {

    mapping(address => bool) public isWhitelisted;
    mapping(uint256 => address) public oracles;

    event OracleActivated(address, uint256);

    /// @dev Setup function sets initial storage of contract.
    /// @param _oracles List of whitelisted oracles.
    function setup(address[] memory _oracles, uint256[] memory _currencyPair)
    public
    onlyOwner
    {
        require(_oracles.length == _currencyPair.length);

        for (uint256 i = 0; i < _oracles.length; i++) {
            address oracle = _oracles[i];
            uint256 cp = _currencyPair[i];
            require(oracle != address(0), "INVALID_DATA:ORACLE_ADDRESS");
            require(cp != uint256(0), "INVALID_DATA:ORACLE_CURRENCY_PAIR");
            oracles[cp] = oracle;
            isWhitelisted[oracle] = true;
            emit OracleActivated(oracle, cp);
        }
    }

    function read(uint256 currencyPair) public view returns (bytes32) {
        address orl = oracles[currencyPair];
        require(isWhitelisted[orl], "INVALID_DATA: CURRENCY_PAIR");
        return DSFeed(orl).read();
    }

    /// @dev Allows to add destination to whitelist. This can only be done via a Safe transaction.
    /// @param oracle Destination address.
    function addToWhitelist(address oracle)
    public
    onlyOwner
    {
        require(oracle != address(0), "Invalid Address provided");
        require(!isWhitelisted[oracle], "Address is already whitelisted");
        isWhitelisted[oracle] = true;
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
}
