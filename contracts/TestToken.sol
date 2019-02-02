pragma solidity ^0.5.0;


contract TestToken {
    mapping(address => uint) public balances;

    event Transfer(address, address);
    constructor(address owner) public {
        balances[owner] = 10000000;
        emit Transfer(address(0), owner);
    }

    function balanceOf(address lookup) public view returns (uint)
    {
        return balances[lookup];
    }

    function transfer(address to, uint value) public returns (bool) {
        if (balances[msg.sender] < value) {
            return false;
        }
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to);

        return true;
    }
}
