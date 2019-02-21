const ProxyFactory = artifacts.require("./ProxyFactory.sol");
const GnosisSafe = artifacts.require("./GnosisSafe.sol");
const StateChannelModule = artifacts.require("./StateChannelModule.sol");
const DailyLimitModule = artifacts.require("./DailyLimitModule.sol")
const SubscriptionModule = artifacts.require("./SubscriptionModule.sol")
const ModuleDataWrapper = artifacts.require("./ModuleDataWrapper.sol")
const SocialRecoveryModule = artifacts.require("./SocialRecoveryModule.sol");
const WhitelistModule = artifacts.require("./WhitelistModule.sol");
const CreateAndAddModules = artifacts.require("./CreateAndAddModules.sol");
const MultiSend = artifacts.require("./MultiSend.sol");
const PayingProxy = artifacts.require("./PayingProxy.sol");
const OracleRegistry = artifacts.require("./OracleRegistry.sol");
const BulkExecutor = artifacts.require("./BulkExecutor.sol");
const DSFeed = artifacts.require("./DSFeed.sol");

const notOwnedAddress = "0x0000000000000000000000000000000000000002"
const notOwnedAddress2 = "0x0000000000000000000000000000000000000003"

module.exports = function (deployer) {

    deployer.deploy(BulkExecutor);

};
