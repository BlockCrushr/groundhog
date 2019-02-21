const fs = require('fs');

const OracleRegistry = artifacts.require("./OracleRegistry.sol");
const SubscriptionModule = artifacts.require("./SubscriptionModule.sol");

const notOwnedAddress = "0x0000000000000000000000000000000000000002"
const notOwnedAddress2 = "0x0000000000000000000000000000000000000003"

const ignoreErrors = function (promise) {
    return promise.catch(function (error) {
        console.log("Failed:", error.tx || error.message)
    })
}

module.exports = async (callback) => {
    var network = 'main'
    var processNext = false
    process.argv.forEach(function (arg) {
        if (processNext) {
            network = arg
            processNext = false
        }
        if (arg.startsWith("--network=")) {
            network = arg.slice(10)
        } else if (arg == "--network") {
            processNext = true
        }
    });

    const ORADDR = '0xBEC8664BDFE35cA6E6AdE337f221c6f07a9b820B';
    const ETHUSDFEED = '0x729D19f657BD0614b4985Cf1D82531c67569197B';
    const OR = await OracleRegistry.at(ORADDR);
    Promise.all([
        ignoreErrors(OR.setup(
            [ETHUSDFEED],
            [web3.utils.fromAscii('ethusd')],
            ['0xc58B09E9C055e976Dd38315F6aaBB34E4335A3eC', '0xcff6bc631100ca645f40fe312b0d91a5cbf0c138'] //networkwallet/executor
        )),
    ])
        .then(function (values) {
            values.forEach(function (resp) {
                if (resp) {
                    console.log("Success:", resp.tx);
                }
            })
            callback("done")
        })
        .catch((err) => {
            callback(err)
        });
}
