var ProxyFactory = artifacts.require("./ProxyFactory.sol");
var GnosisSafe = artifacts.require("./GnosisSafe.sol");
var StateChannelModule = artifacts.require("./StateChannelModule.sol");
var DailyLimitModule = artifacts.require("./DailyLimitModule.sol")
var SubscriptionModule = artifacts.require("./SubscriptionModule.sol")
var ModuleDataWrapper = artifacts.require("./ModuleDataWrapper.sol")
var SocialRecoveryModule = artifacts.require("./SocialRecoveryModule.sol");
var WhitelistModule = artifacts.require("./WhitelistModule.sol");
var CreateAndAddModules = artifacts.require("./CreateAndAddModules.sol");
var MultiSend = artifacts.require("./MultiSend.sol");
var PayingProxy = artifacts.require("./PayingProxy.sol");
var OracleRegistry = artifacts.require("./OracleRegistry.sol");
var DSFeed = artifacts.require("./DSFeed.sol");

const notOwnedAddress = "0x0000000000000000000000000000000000000002"
const notOwnedAddress2 = "0x0000000000000000000000000000000000000003"

module.exports = function (deployer) {


    deployer.deploy(ProxyFactory, PayingProxy.bytecode)
    deployer.deploy(DSFeed).then(feed => {
        return deployer.deploy(OracleRegistry).then(or => {
            or.setup([feed], [web3.utils.fromAscii('ethusd')])
        })
    })
    deployer.deploy(GnosisSafe).then(function (safe) {
        safe.setup([notOwnedAddress], 1, 0, 0)
        return safe
    });

    deployer.deploy(SubscriptionModule).then(function (module) {
        module.setup(notOwnedAddress)
        return module;
    });
    deployer.deploy(ModuleDataWrapper).then(function (module) {
        module.setup()
        return module;
    });
    // deployer.deploy(StateChannelModule).then(function (module) {
    //     //     module.setup()
    //     //     return module
    //     // });
    //     // deployer.deploy(DailyLimitModule).then(function (module) {
    //     //     module.setup([],[])
    //     //     return module
    //     // });
    //     // deployer.deploy(SocialRecoveryModule).then(function (module) {
    //     //     module.setup([notOwnedAddress, notOwnedAddress2], 2)
    //     //     return module
    //     // });
    //     // deployer.deploy(WhitelistModule).then(function (module) {
    //     //     module.setup([])
    //     //     return module
    //     // });
    deployer.deploy(CreateAndAddModules);
    deployer.deploy(MultiSend);
};
