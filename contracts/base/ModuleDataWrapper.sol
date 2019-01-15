pragma solidity ^0.5.0;

contract ModuleDataWrapper {

    event Data(bytes);
    function setup(bytes memory data)
    public
    {
        emit Data(data);
    }
}