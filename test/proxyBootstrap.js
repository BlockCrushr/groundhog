// const utils = require('./utils')
// const BigNumber = require('bignumber.js')
// const timeHelper = require('./time')
// const PayingProxy = artifacts.require("./PayingProxy.sol")
// const PayingProxyBoot = artifacts.require("./PayingProxyBootstrap.sol")
// const lw = require('eth-lightwallet');
//
// const {
//     getContractInstance,
//     create2Address,
//     num2uint
// } = require("./helpers")
//
// const getInstance = getContractInstance(web3)
//
// const create2 = create2Address;
// const convertNum = num2uint;
// const GAS_PRICE = web3.utils.toWei('20', 'gwei')
//
// contract('PayingProxyBootstrap', async (accounts) => {
//
//     let gnosisSafe;
//     let multiSend;
//     let bulkExecutor;
//     let merchantSafe;
//     let subscriptionModule;
//     let merchantModule;
//     let executor = accounts[8];
//     let receiver = accounts[9];
//     let networkWallet = accounts[5];
//     let masterCopy;
//     let mc2;
//
//
//     const CALL = 0;
//
//     const DELEGATECALL = 1;
//     let signTypedData = async (account, data) => {
//         return new Promise(function (resolve, reject) {
//             try {
//                 web3.currentProvider.send({
//                     method: "eth_signTypedData",
//                     params: [account, data],
//                     from: account
//                 }, function (err, response) {
//                     if (err) {
//                         return reject(err);
//                     }
//                     if (response.error) {
//                         reject(response.error)
//                     }
//                     resolve(response.result);
//                 });
//             } catch (e) {
//                 reject(e);
//             }
//
//         });
//     }
//
//     let signer = async (
//         confirmingAccounts,
//         to,
//         value,
//         data,
//         operation,
//         txGasEstimate,
//         dataGasEstimate,
//         gasPrice,
//         gasToken,
//         refundReceiver,
//         meta
//     ) => {
//         let typedData = {
//             types: {
//                 EIP712Domain: [
//                     {type: "address", name: "verifyingContract"}
//                 ],
//                 // "SafeSubTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes meta)"
//                 SafeSubTx: [
//                     {type: "address", name: "to"},
//                     {type: "uint256", name: "value"},
//                     {type: "bytes", name: "data"},
//                     {type: "uint8", name: "operation"},
//                     {type: "uint256", name: "safeTxGas"},
//                     {type: "uint256", name: "dataGas"},
//                     {type: "uint256", name: "gasPrice"},
//                     {type: "address", name: "gasToken"},
//                     {type: "address", name: "refundReceiver"},
//                     {type: "bytes", name: "meta"},
//                 ]
//             },
//             domain: {
//                 verifyingContract: subscriptionModule.options.address
//             },
//             primaryType: "SafeSubTx",
//             message: {
//                 to: to,
//                 value: value,
//                 data: data,
//                 operation: operation,
//                 safeTxGas: txGasEstimate,
//                 dataGas: dataGasEstimate,
//                 gasPrice: gasPrice,
//                 gasToken: gasToken,
//                 refundReceiver: refundReceiver,
//                 meta: meta
//             }
//         };
//
//         let signatureBytes = "0x";
//         confirmingAccounts.sort();
//         for (let i = 0; i < confirmingAccounts.length; i++) {
//             signatureBytes += (await signTypedData(confirmingAccounts[i], typedData)).replace('0x', '')
//         }
//         return signatureBytes
//     }
//
//     let cancelSigner = async (
//         confirmingAccounts,
//         subscriptionHash
//     ) => {
//         let typedData = {
//             types: {
//                 EIP712Domain: [
//                     {type: "address", name: "verifyingContract"}
//                 ],
//                 //"SafeSubCancelTx(bytes32 subscriptionHash, string action)"
//                 SafeSubCancelTx: [
//                     {type: "bytes32", name: "subscriptionHash"},
//                     {type: "string", name: "action"},
//                 ]
//             },
//             domain: {
//                 verifyingContract: subscriptionModule.options.address
//             },
//             primaryType: "SafeSubCancelTx",
//             message: {
//                 subscriptionHash: subscriptionHash,
//                 action: "cancel"
//             }
//         };
//
//         let signatureBytes = "0x";
//         confirmingAccounts.sort();
//         for (let i = 0; i < confirmingAccounts.length; i++) {
//             signatureBytes += (await signTypedData(confirmingAccounts[i], typedData)).replace('0x', '')
//         }
//         return signatureBytes
//     }
//
//     let txSigner = async (
//         confirmingAccounts,
//         to,
//         value,
//         data,
//         operation,
//         txGasEstimate,
//         dataGasEstimate,
//         gasPrice,
//         gasToken,
//         refundReceiver,
//         nonce,
//         safe = null
//     ) => {
//         let typedData = {
//             types: {
//                 EIP712Domain: [
//                     {type: "address", name: "verifyingContract"}
//                 ],
//                 // "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
//                 SafeTx: [
//                     {type: "address", name: "to"},
//                     {type: "uint256", name: "value"},
//                     {type: "bytes", name: "data"},
//                     {type: "uint8", name: "operation"},
//                     {type: "uint256", name: "safeTxGas"},
//                     {type: "uint256", name: "dataGas"},
//                     {type: "uint256", name: "gasPrice"},
//                     {type: "address", name: "gasToken"},
//                     {type: "address", name: "refundReceiver"},
//                     {type: "uint256", name: "nonce"},
//                 ]
//             },
//             domain: {
//                 verifyingContract: safe || gnosisSafe.options.address
//             },
//             primaryType: "SafeTx",
//             message: {
//                 to: to,
//                 value: value,
//                 data: data,
//                 operation: operation,
//                 safeTxGas: txGasEstimate,
//                 dataGas: dataGasEstimate,
//                 gasPrice: gasPrice,
//                 gasToken: gasToken,
//                 refundReceiver: refundReceiver,
//                 nonce: nonce
//             }
//         }
//
//         let signatureBytes = "0x"
//         confirmingAccounts.sort();
//         for (let i = 0; i < confirmingAccounts.length; i++) {
//             signatureBytes += (await signTypedData(confirmingAccounts[i], typedData)).replace('0x', '')
//         }
//         return signatureBytes
//     }
//
//
//
//
//     beforeEach(async () => {
//
//
//         bulkExecutor = await getInstance("BulkExecutor", {create: true});
//
//         masterCopy = await getInstance("MasterCopy", {create: true});
//
//         multiSend = await getInstance("MultiSend", {create: true});
//
//         let createAndAddModules = await getInstance("CreateAndAddModules", {create: true});
//
//
//         let ethusdOracle = await getInstance("DSFeed", {create: true});
//
//         let proxyFactory = await getInstance("ProxyFactory", {
//             create: true,
//             constructorArgs: PayingProxy.bytecode
//         });
//
//         let mdw = await getInstance("ModuleDataWrapper", {create: true});
//         //setup master copies
//
//         let gnosisSafeMasterCopy = await getInstance("GnosisSafe", {create: true});
//
//         let masterCopySetupTx = await gnosisSafeMasterCopy.methods.setup(
//             [accounts[0], accounts[1], accounts[2]], 2,
//             "0x0000000000000000000000000000000000000002", "0x"
//         ).send({
//             from: accounts[0],
//             gasLimit: 8000000
//         });
//
//         let subscriptionModuleMasterCopy = await getInstance("SubscriptionModule", {create: true});
//         mc2 = await getInstance("SubscriptionModule", {create: true});
//
//         tx = await subscriptionModuleMasterCopy.methods.setup(
//             "0x0000000000000000000000000000000000000002"
//         ).send({
//             from: accounts[0],
//             gasLimit: 8000000
//         })
//
//         tx = await mc2.methods.setup(
//             "0x0000000000000000000000000000000000000002"
//         ).send({
//             from: accounts[0],
//             gasLimit: 8000000
//         })
//
//
//         let oracleRegistry = await getInstance("OracleRegistry", {create: true});
//
//
//         tx = await oracleRegistry.methods.setup(
//             [ethusdOracle.options.address],
//             [web3.utils.fromAscii('ethusd')],
//             [networkWallet, bulkExecutor.options.address]
//         ).send({
//             from: accounts[0],
//             gasLimit: 8000000
//         });
//
//         let merchantModuleMasterCopy = await getInstance("MerchantModule", {create: true});
//
//         tx = await merchantModuleMasterCopy.methods.setup(
//             oracleRegistry.options.address
//         ).send({
//             from: accounts[0],
//             gasLimit: 8000000
//         });
//
//         // Subscription module setup
//         let subscriptionModuleSetupData = await subscriptionModuleMasterCopy.methods.setup(
//             oracleRegistry.options.address
//         ).encodeABI();
//
//         let subscriptionModuleCreationData = await proxyFactory.methods.createProxy(
//             subscriptionModuleMasterCopy.options.address,
//             subscriptionModuleSetupData
//         ).encodeABI();
//
//         // Merchant module setup
//         let merchantModuleSetupData = await subscriptionModuleMasterCopy.methods.setup(
//             oracleRegistry.options.address
//         ).encodeABI();
//
//         let merchantModuleCreationData = await proxyFactory.methods.createProxy(
//             merchantModuleMasterCopy.options.address,
//             merchantModuleSetupData
//         ).encodeABI();
//
//         // let modulesCreationData = utils.createAndAddModulesData([subscriptionModuleCreationData])
//         let modulesCreationData = [subscriptionModuleCreationData].reduce((acc, data) => acc + mdw.methods.setup(data)
//             .encodeABI().substr(74), "0x")
//         //called as apart of the setup, currently doesn't work when initialized through the constructor paying proxy workflow
//         let createAndAddModulesData = await createAndAddModules.methods.createAndAddModules(
//             proxyFactory.options.address,
//             modulesCreationData
//         ).encodeABI();
//
//
//         let merchantModulesCreationData = [merchantModuleCreationData].reduce((acc, data) => acc + mdw.methods.setup(data)
//             .encodeABI().substr(74), "0x")
//         //called as apart of the setup, currently doesn't work when initialized through the constructor paying proxy workflow
//         let merchantCreateAndAddModulesData = await createAndAddModules.methods.createAndAddModules(
//             proxyFactory.options.address,
//             merchantModulesCreationData
//         ).encodeABI();
//
//         // Create Gnosis Safe
//         // let gnosisSafeData = await gnosisSafeMasterCopy.methods.setup([oracles[0], oracles[1], oracles[2]], 1, oracles[2], '0x').encodeABI();
//         let gnosisSafeData = await gnosisSafeMasterCopy.methods.setup(
//             [accounts[0], accounts[1], accounts[2]],
//             1,
//             createAndAddModules.options.address,
//             createAndAddModulesData
//         ).encodeABI();
//
//         let merchantSafeData = await gnosisSafeMasterCopy.methods.setup(
//             [accounts[0], accounts[1], accounts[2]],
//             1,
//             createAndAddModules.options.address,
//             merchantCreateAndAddModulesData
//         ).encodeABI();
//
//         // let salt = convertNum(1337);
//         // let create2Address = create2(
//         //     proxyFactory.options.address,
//         //     salt,
//         //     PayingProxy.bytecode
//         // );
//
//         // await web3.eth.sendTransaction({
//         //     from: accounts[0],
//         //     to: create2Address,
//         //     value: web3.utils.toWei('0.005', 'ether')
//         // });
//
//
//         //address[] memory masterCopy,
//         //         bytes memory moduleSetupData,
//         //         address[] memory owners,
//         //         uint256 threshold,
//         //         address createAddAddr,
//         //         address payable funder,
//         //         address paymentToken,
//         //         uint256 payment
//
//
//         // let ppbSetuptx = await payingProxyBootstrap.methods.setup(
//         //     [
//         //         subscriptionModuleMasterCopy.options.address,
//         //         gnosisSafeMasterCopy.options.address
//         //     ], //mastercopies
//         //     subscriptionModuleSetupData, //moduleSetupData
//         //     [
//         //         accounts[0], accounts[1], accounts[2]
//         //     ],
//         //     1, //threshold
//         //     createAndAddModules.options.address, //createAddmodules addy
//         //     executor, //funder
//         //     "0x0000000000000000000000000000000000000000", //paymentToken
//         //     0 //payment
//         // ).send({
//         //     from: accounts[0],
//         //     gasLimit:8000000
//         // })
//
//         // let payingProxyBootstrap = await getInstance(
//         //     "PayingProxyBootstrap",
//         //     {
//         //         create: true
//         //     }
//         // )
//
//         let masterCopies = [
//             subscriptionModuleMasterCopy.options.address,
//             gnosisSafeMasterCopy.options.address
//         ];
//
//
//         let owners = [
//             accounts[0], accounts[1], accounts[2]
//         ];
//
//         let threshold = 1;
//
//         let createAddAddr = createAndAddModules.options.address;
//         let funder = executor;
//         let payToken = "0x0000000000000000000000000000000000000000";
//         let payment = 0;
//
//         let bootstrapp_address = lw.txutils.createdContractAddress(accounts[0], await web3.eth.getTransactionCount(accounts[0]))
//         let sub_module_address = lw.txutils.createdContractAddress(bootstrapp_address, 1)
//         let gnosis_safe_adress = lw.txutils.createdContractAddress(bootstrapp_address, 2)
//
//         ppb = await getInstance("PayingProxyBootstrap", {
//                 create: true, constructorArgs: [
//                     subscriptionModuleMasterCopy.options.address,
//                     gnosisSafeMasterCopy.options.address,
//                     subscriptionModuleSetupData,
//                     owners,
//                     threshold,
//                     createAndAddModules.options.address,
//                     funder,
//                     payToken,
//                     payment
//                 ]
//             }
//         );
//
//         //
//         // merchantSafe = await utils.getParamFromTxEvent(
//         //     await proxyFactory.methods.createProxy(
//         //         gnosisSafeMasterCopy.options.address,
//         //         merchantSafeData
//         //     ).send({from: accounts[0], gasLimit: 8000000}),
//         //     'ProxyCreation',
//         //     'proxy',
//         //     proxyFactory.options.address,
//         //     'GnosisSafe',
//         //     'create Merchant Gnosis Safe',
//         //     getInstance
//         // );
//
//         gnosisSafe = await getInstance("GnosisSafe", {deployedAddress: gnosis_safe_adress})
//
//         let modules = await gnosisSafe.methods.getModules().call()
//         subscriptionModule = await getInstance('SubscriptionModule', {deployedAddress: modules[0]})
//         assert.equal(await subscriptionModule.methods.manager().call(), gnosisSafe.options.address)
//
//         // let merchantModules = await merchantSafe.methods.getModules().call()
//         // merchantModule = await getInstance('merchantModule', {deployedAddress: merchantModules[0]})
//         // assert.equal(await merchantModule.methods.manager().call(), merchantSafe.options.address)
//     })
//
//
//     it('Should WOrk', async () => {
//         assert.ok(false)
//     })
// })
//
