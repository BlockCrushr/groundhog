pragma solidity ^0.5.0;

import "../base/Module.sol";
import "../external/Math.sol";
import "../OracleRegistry.sol";
import "../common/SecuredTokenTransfer.sol";


interface ERC20 {
    function totalSupply() external view returns (uint256 supply);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value) external returns (bool success);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    function decimals() external view returns (uint256 digits);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


contract PaymentSplitter is Module, SecuredTokenTransfer {

    using DSMath for uint256;

    OracleRegistry public oracleRegistry;

    event IncomingPayment(uint256 payment);
    event PaymentSent(address asset, address receiver, uint256 payment);
//    event LogUint(uint, string);
//    event LogAddress(address, string);
//    event LogBytes32(bytes32, string);

    function setup(address _oracleRegistry)
    public
    {
        setManager();
        require(
            address(oracleRegistry) == address(0),
            "PaymentSplitter::setup: INVALID_STATE: ORACLE_REGISTRY_SET"
        );
        oracleRegistry = OracleRegistry(_oracleRegistry);
    }

    function()
    payable
    external
    {
        emit IncomingPayment(msg.value);
        //        require(split(address(0)), "Split Failed");
    }

    function split(address tokenAddress)
    public
    returns (bool)
    {
        require(
            msg.sender == oracleRegistry.getNetworkExecutor(),
            "PaymentSplitter::split: INVALID_DATA: MSG_SENDER_NOT_EXECUTOR"
        );

        address payable networkWallet = oracleRegistry.getNetworkWallet();
        address payable merchantWallet = address(manager);

        if (tokenAddress == address(0)) {

            uint256 splitterBalanceStart = address(this).balance;
            if(splitterBalanceStart == 0) return false;
//            emit LogUint(splitterBalanceStart, "splitterBalanceStart");
            //
            uint256 fee = oracleRegistry.getNetworkFee(address(0));
//            emit LogUint(fee, "fee");


            uint256 networkBalanceStart = networkWallet.balance;
//            emit LogUint(networkBalanceStart, "networkBalanceStart");

            uint256 merchantBalanceStart = merchantWallet.balance;

//            emit LogUint(merchantBalanceStart, "merchantBalanceStart");

            uint256 networkSplit = splitterBalanceStart.wmul(fee);
//            emit LogUint(networkSplit, "networkSplit");

            uint256 merchantSplit = splitterBalanceStart.sub(networkSplit);

//            emit LogUint(merchantSplit, "merchantSplit");

            require(merchantSplit > networkSplit, "Split Math is Wrong");
            //pay network

            networkWallet.transfer(networkSplit);
            emit PaymentSent(address(0x0), networkWallet, networkSplit);
            //pay merchant

            merchantWallet.transfer(merchantSplit);
            emit PaymentSent(address(0x0), merchantWallet, merchantSplit);

            require(
                (networkBalanceStart.add(networkSplit) == networkWallet.balance)
                &&
                (merchantBalanceStart.add(merchantSplit) == merchantWallet.balance),
                "PaymentSplitter::withdraw: INVALID_EXEC SPLIT_PAYOUT"
            );
        } else {

            ERC20 token = ERC20(tokenAddress);

            uint256 splitterBalanceStart = token.balanceOf(address(this));
//            emit LogUint(splitterBalanceStart, "splitterBalanceStart");


            if(splitterBalanceStart == 0) return false;

            uint256 fee = oracleRegistry.getNetworkFee(address(token));

//            emit LogUint(fee, "fee");

            uint256 merchantBalanceStart = token.balanceOf(merchantWallet);

//            emit LogUint(merchantBalanceStart, "merchantBalanceStart");

            uint256 networkSplit = splitterBalanceStart.wmul(fee);

//            emit LogUint(networkSplit, "networkSplit");

            uint256 merchantSplit = splitterBalanceStart.sub(networkSplit);

//            emit LogUint(merchantSplit, "merchantSplit");

            require(
                networkSplit.add(merchantSplit) == splitterBalanceStart,
                "PaymentSplitter::withdraw: INVALID_EXEC TOKEN_SPLIT"
            );

            //pay network

            require(
                transferToken(address(token), networkWallet, networkSplit),
                "PaymentSplitter::withdraw: INVALID_EXEC TOKEN_NETWORK_PAYOUT"
            );

            emit PaymentSent(address(token), networkWallet, networkSplit);

            //pay merchant
            require(
                transferToken(address(token), merchantWallet, merchantSplit),
                "PaymentSplitter::withdraw: INVALID_EXEC TOKEN_MERCHANT_PAYOUT"
            );
            emit PaymentSent(address(token), merchantWallet, merchantSplit);
        }
        return true;
    }
}
