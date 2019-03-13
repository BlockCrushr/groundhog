const ProxyFactory = artifacts.require("./ProxyFactory.sol");
const PayingProxy = artifacts.require("./PayingProxy.sol");
const GnosisSafe = artifacts.require("./GnosisSafe.sol");
const SubscriptionModule = artifacts.require("./SubscriptionModule.sol")
const MerchantModule = artifacts.require("./MerchantModule.sol")

const CreateAndAddModules = artifacts.require("./CreateAndAddModules.sol");
const OracleRegistry = artifacts.require("./OracleRegistry.sol");
const BulkExecutor = artifacts.require("./BulkExecutor.sol");

module.exports = async (deployer) => {

    deployer.deploy(BulkExecutor);
    deployer.deploy(OracleRegistry);
    deployer.deploy(SubscriptionModule);
    deployer.deploy(MerchantModule);
    deployer.deploy(CreateAndAddModules);
    deployer.deploy(ProxyFactory)
    deployer.deploy(GnosisSafe)

};
