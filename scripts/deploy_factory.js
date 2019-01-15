const ProxyFactory = artifacts.require("./ProxyFactory.sol");
const Proxy = artifacts.require("./Proxy.sol");

module.exports = function(callback) {
    ProxyFactory.new().then(function(instance) {
            instance.setup(Proxy.bytecode);
            console.log("Deployment success:", instance.address)
            callback("done")
        }).catch(function(err) {
            console.log("Deployment failed:", err.tx)
            callback("done")
        });
}