// const utils = require('./utils')
// const safeUtils = require('./utilsPersonalSafe')
// const solc = require('solc')
//
// const CreateAndAddModules = artifacts.require("./libraries/CreateAndAddModules.sol");
// const GnosisSafe = artifacts.require("./GnosisSafe.sol")
// const ProxyFactory = artifacts.require("./ProxyFactory.sol")
// const SocialRecoveryModule = artifacts.require("./SocialRecoveryModule.sol");
// const StateChannelModule = artifacts.require("./modules/StateChannelModule.sol");
//
//
// contract('CreateAndAddModules', function(oracles) {
//
//     let gnosisSafe
//     let lw
//     let executor = oracles[8]
//
//     const CALL = 0
//     const CREATE = 2
//
//     it('should create safe with multiple modules', async () => {
//         // Create lightwallet
//         lw = await utils.createLightwallet()
//         // Create libraries
//         let createAndAddModules = await CreateAndAddModules.new()
//         // Create Master Copies
//         let proxyFactory = await ProxyFactory.new()
//         let gnosisSafeMasterCopy = await GnosisSafe.new()
//         gnosisSafeMasterCopy.setup([lw.oracles[0], lw.oracles[1], lw.oracles[2]], 2, 0, "0x")
//         let stateChannelModuleMasterCopy = await StateChannelModule.new()
//         stateChannelModuleMasterCopy.setup()
//         let socialRecoveryModuleMasterCopy = await SocialRecoveryModule.new()
//         socialRecoveryModuleMasterCopy.setup([oracles[0], oracles[1]], 2)
//
//         // Create module data
//         let recoverySetupData = await socialRecoveryModuleMasterCopy.contract.setup.getData([oracles[2], oracles[3]], 2)
//         let recoveryCreationData = await proxyFactory.contract.createProxy.getData(socialRecoveryModuleMasterCopy.address, recoverySetupData)
//         let stateChannelSetupData = await stateChannelModuleMasterCopy.contract.setup.getData()
//         let stateChannelCreationData = await proxyFactory.contract.createProxy.getData(stateChannelModuleMasterCopy.address, stateChannelSetupData)
//
//         // Create library data
//         let modulesCreationData = utils.createAndAddModulesData([recoveryCreationData,stateChannelCreationData])
//         let createAndAddModulesData = createAndAddModules.contract.createAndAddModules.getData(proxyFactory.address, modulesCreationData)
//
//         // Create Gnosis Safe
//         let gnosisSafeData = await gnosisSafeMasterCopy.contract.setup.getData([oracles[0], oracles[1], oracles[2]], 2, createAndAddModules.address, createAndAddModulesData)
//         gnosisSafe = utils.getParamFromTxEvent(
//             await proxyFactory.createProxy(gnosisSafeMasterCopy.address, gnosisSafeData),
//             'ProxyCreation', 'proxy', proxyFactory.address, GnosisSafe, 'create Gnosis Safe',
//         )
//
//         let modules = await gnosisSafe.getModules()
//         assert.equal(2, modules.length)
//     })
// })
