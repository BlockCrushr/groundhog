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

const notOwnedAddress = "0x0000000000000000000000000000000000000002"
const notOwnedAddress2 = "0x0000000000000000000000000000000000000003"

module.exports = function(deployer) {

    // let proxyCode = "0x608060405234801561001057600080fd5b506105f4806100206000396000f3fe608060405260043610610057576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680634555d5c9146100965780635c60da1b146100c15780639cfce92514610118575b73ffffffffffffffffffffffffffffffffffffffff600054163660008037600080366000845af43d6000803e6000811415610091573d6000fd5b3d6000f35b3480156100a257600080fd5b506100ab6101b3565b6040518082815260200191505060405180910390f35b3480156100cd57600080fd5b506100d66101bc565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561012457600080fd5b506101b16004803603608081101561013b57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803590602001909291905050506101e5565b005b60006003905090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b600073ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff16141515156102b0576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260248152602001807f496e76616c6964206d617374657220636f707920616464726573732070726f7681526020017f696465640000000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b836000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555060008111156104a957600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff161415610402578273ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f1935050505015156103fd576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260268152602001807f436f756c64206e6f74207061792073616665206372656174696f6e207769746881526020017f206574686572000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b6104a8565b61040d8284836104af565b15156104a7576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260268152602001807f436f756c64206e6f74207061792073616665206372656174696f6e207769746881526020017f20746f6b656e000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b5b5b50505050565b600060608383604051602401808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001828152602001925050506040516020818303038152906040527fa9059cbb000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19166020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff838183161783525050505090506000808251602084016000896127105a03f16040513d6000823e3d600081146105ab57602081146105b357600094506105bd565b8294506105bd565b8151158315171594505b50505050939250505056fea165627a7a723058206d16b69660e52db7bb1a03d44a58dbcbb5d6ddbce115841020362222c1fafd2c0029";

    deployer.deploy(ProxyFactory, PayingProxy.bytecode)
    deployer.deploy(GnosisSafe).then(function (safe) {
        safe.setup([notOwnedAddress], 1, 0, 0)
        return safe
    });

    deployer.deploy(SubscriptionModule).then(function (module) {
        module.setup()
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
