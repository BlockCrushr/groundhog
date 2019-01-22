// const utils = require('./utils')
//
// const CreateAndAddModules = artifacts.require("./libraries/CreateAndAddModules.sol");
// const ProxyFactory = artifacts.require("./ProxyFactory.sol");
// const GnosisSafe = artifacts.require("./GnosisSafe.sol");
// const SocialRecoveryModule = artifacts.require("./SocialRecoveryModule.sol");
//
//
// contract('SocialRecoveryModule', function(oracles) {
//
//     let gnosisSafe
//     let socialRecoveryModule
//
//     const CALL = 0
//
//     beforeEach(async function () {
//         // Create Master Copies
//         let proxyFactory = await ProxyFactory.new()
//         let createAndAddModules = await CreateAndAddModules.new()
//         let gnosisSafeMasterCopy = await GnosisSafe.new()
//         // Initialize safe master copy
//         gnosisSafeMasterCopy.setup([oracles[0], oracles[1]], 2, 0, "0x")
//         let socialRecoveryModuleMasterCopy = await SocialRecoveryModule.new()
//         // Initialize module master copy
//         socialRecoveryModuleMasterCopy.setup([oracles[0], oracles[1]], 2)
//         // Create Gnosis Safe and Social Recovery Module in one transactions
//         let moduleData = await socialRecoveryModuleMasterCopy.contract.setup.getData([oracles[2], oracles[3]], 2)
//         let proxyFactoryData = await proxyFactory.contract.createProxy.getData(socialRecoveryModuleMasterCopy.address, moduleData)
//         let modulesCreationData = utils.createAndAddModulesData([proxyFactoryData])
//         let createAndAddModulesData = createAndAddModules.contract.createAndAddModules.getData(proxyFactory.address, modulesCreationData)
//         let gnosisSafeData = await gnosisSafeMasterCopy.contract.setup.getData([oracles[0], oracles[1]], 2, createAndAddModules.address, createAndAddModulesData)
//         gnosisSafe = utils.getParamFromTxEvent(
//             await proxyFactory.createProxy(gnosisSafeMasterCopy.address, gnosisSafeData),
//             'ProxyCreation', 'proxy', proxyFactory.address, GnosisSafe, 'create Gnosis Safe and Social Recovery Module',
//         )
//         let modules = await gnosisSafe.getModules()
//         socialRecoveryModule = SocialRecoveryModule.at(modules[0])
//         assert.equal(await socialRecoveryModule.manager.call(), gnosisSafe.address)
//     })
//
//     it('should allow to replace an owner approved by friends', async () => {
//         // Replace non existing owner
//         let data = await gnosisSafe.contract.swapOwner.getData("0x1", oracles[8], oracles[9])
//         // Confirm transaction to be executed without confirmations
//         let dataHash = await socialRecoveryModule.getDataHash(data)
//         await socialRecoveryModule.confirmTransaction(dataHash, {from: oracles[3]})
//         await socialRecoveryModule.confirmTransaction(dataHash, {from: oracles[2]})
//         await utils.assertRejects(
//             socialRecoveryModule.recoverAccess(data, {from: oracles[3]}),
//             "Owner does not exist"
//         )
//
//         // Replace owner
//         data = await gnosisSafe.contract.swapOwner.getData("0x1", oracles[0], oracles[9])
//         // Confirm transaction to be executed without confirmations
//         dataHash = await socialRecoveryModule.getDataHash(data)
//         await socialRecoveryModule.confirmTransaction(dataHash, {from: oracles[3]})
//         await utils.assertRejects(
//             socialRecoveryModule.recoverAccess("0x1", oracles[0], oracles[9], {from: oracles[3]}),
//             "It was not confirmed by the required number of friends"
//         )
//         // Confirm with 2nd friend
//         utils.logGasUsage("confirm recovery", await socialRecoveryModule.confirmTransaction(dataHash, {from: oracles[2]}))
//         utils.logGasUsage("recover access", await socialRecoveryModule.recoverAccess("0x1", oracles[0], oracles[9], {from: oracles[3]}))
//         assert.equal(await gnosisSafe.isOwner(oracles[9]), true);
//     })
// });
