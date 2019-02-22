pragma solidity ^0.5.0;

import "../base/Module.sol";
import "./interfaces/SubscriptionModule.sol";
import "../external/Math.sol";
import "../interfaces/OracleRegistryI.sol";
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


contract MerchantModule is Module, SecuredTokenTransfer {

    using DSMath for uint256;

    OracleRegistryI public oracleRegistry;

    event PaymentSent(address asset, address receiver, uint256 payment);


    function setup(address _oracleRegistry)
    public
    {
        setManager();
        require(
            address(oracleRegistry) == address(0),
            "MerchantModule::setup: INVALID_STATE: ORACLE_REGISTRY_SET"
        );
        oracleRegistry = OracleRegistryI(_oracleRegistry);
    }

    function()
    payable
    external
    {
    }

    function split(
        address tokenAddress
    )
    public
    returns (bool)
    {
        require(
            msg.sender == oracleRegistry.getNetworkExecutor(),
            "MerchantModule::split: INVALID_DATA: MSG_SENDER_NOT_EXECUTOR"
        );

        address payable networkWallet = oracleRegistry.getNetworkWallet();
        address payable merchantWallet = address(manager);

        if (tokenAddress == address(0)) {

            uint256 splitterBalanceStart = address(this).balance;
            if (splitterBalanceStart == 0) return false;
            //
            uint256 fee = oracleRegistry.getNetworkFee(address(0));


            uint256 networkBalanceStart = networkWallet.balance;

            uint256 merchantBalanceStart = merchantWallet.balance;


            uint256 networkSplit = splitterBalanceStart.wmul(fee);

            uint256 merchantSplit = splitterBalanceStart.sub(networkSplit);


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
                "MerchantModule::withdraw: INVALID_EXEC SPLIT_PAYOUT"
            );
        } else {

            ERC20 token = ERC20(tokenAddress);

            uint256 splitterBalanceStart = token.balanceOf(address(this));


            if (splitterBalanceStart == 0) return false;

            uint256 fee = oracleRegistry.getNetworkFee(address(token));


            uint256 merchantBalanceStart = token.balanceOf(merchantWallet);

            uint256 networkBalanceStart = token.balanceOf(networkWallet);


            uint256 networkSplit = splitterBalanceStart.wmul(fee);


            uint256 merchantSplit = splitterBalanceStart.sub(networkSplit);


            require(
                networkSplit.add(merchantSplit) == splitterBalanceStart,
                "MerchantModule::withdraw: INVALID_EXEC TOKEN_SPLIT"
            );

            //pay network

            require(
                transferToken(address(token), networkWallet, networkSplit),
                "MerchantModule::withdraw: INVALID_EXEC TOKEN_NETWORK_PAYOUT"
            );

            emit PaymentSent(address(token), networkWallet, networkSplit);

            //pay merchant
            require(
                transferToken(address(token), merchantWallet, merchantSplit),
                "MerchantModule::withdraw: INVALID_EXEC TOKEN_MERCHANT_PAYOUT"
            );
            emit PaymentSent(address(token), merchantWallet, merchantSplit);

            require(
                (networkBalanceStart.add(networkSplit) == token.balanceOf(networkWallet))
                &&
                (merchantBalanceStart.add(merchantSplit) == token.balanceOf(merchantWallet)),
                "MerchantModule::withdraw: INVALID_EXEC TOKEN_SPLIT_PAYOUT"
            );
        }
        return true;
    }


    function cancelCXSubscription(
        address customer,
        address to,
        uint256 value,
        bytes memory data,
        uint256 period,
        uint256 offChainId,
        uint256 startDate,
        uint256 endDate,
        bytes memory signatures
    )
    public
    authorized
    {
        SM(customer).cancelSubscriptionAsRecipient(
            to,
            value,
            data,
            period,
            offChainId,
            startDate,
            endDate,
            signatures
        );
    }

}
