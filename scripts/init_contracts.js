const fs = require('fs');

const OracleRegistry = artifacts.require("./OracleRegistry.sol");
const SubscriptionModule = artifacts.require("./SubscriptionModule.sol");
const MerchantModule = artifacts.require("./MerchantModule.sol");

const notOwnedAddress = "0x0000000000000000000000000000000000000002"
const notOwnedAddress2 = "0x0000000000000000000000000000000000000003"

const ignoreErrors = function (promise) {
    return promise.catch(function (error) {
        console.log("Failed:", error.tx || error.message)
    })
}

module.exports = (callback) => {
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

    const ORADDR = '0xF253300Bd9Ed0C6aE046edD614196FD8950Ef31f';

    const SMADDR = '0x12a1f243Fb1348510C6Ce7842B5d3c0C43138Ef1';

    const MMADDR = '0xd18D5c0c18B4305fdfC3bECdA6a871E719264609';

    const ETHUSDFEED = '0xa5aA4e07F5255E14F02B385b1f04b35cC50bdb66';

    const EXECUTOR = '0x299C280963E0fd9BE70b1061Dd49D92c1117E02E';

    const NETWORKWALLET = '0x72fE0d6A3E4CB16918A1c658f0856f3D9c64e3d4';

    Promise.all([
            // OracleRegistry.at(ORADDR).then(instance => {
            //     return instance.setup(
            //         [ETHUSDFEED],
            //         [web3.utils.fromAscii('ethusd')],
            //         ["0x0000000000000000000000000000000000000000"],
            //         [NETWORKWALLET, EXECUTOR]
            //     )
            // }),
            // SubscriptionModule.at(SMADDR).then(instance => {
            //     return instance.setup(
            //         notOwnedAddress
            //     )
            // }),
            MerchantModule.at(MMADDR).then(instance => {
                return instance.setup(
                    notOwnedAddress
                )
            })
        ]
    ).then(function (values) {
        values.forEach(function (resp) {
            if (resp) {
                console.log("Success:", resp.tx);
            }
        })
        callback("done")
    }).catch((err) => {
        callback(err)
    });
};
