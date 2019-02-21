pragma solidity ^0.5.0;

interface MMInterface {
    function split(
        address tokenAddress
    )
    external
    returns (bool);
}
