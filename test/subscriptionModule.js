// const utils = require('./utils')
// const BigNumber = require('bignumber.js')
// const timeHelper = require('./time')
// const PayingProxy = artifacts.require("./PayingProxy.sol")
//
//
// const {
//     getContractInstance,
//     create2Address,
//     num2uint
// } = require("./helpers")
// const getInstance = getContractInstance(web3)
//
// const create2 = create2Address;
// const convertNum = num2uint;
// const GAS_PRICE = web3.utils.toWei('20', 'gwei')
//
// contract('SubscriptionModule', async (accounts) => {
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
//     let estimateDataGas = (to, value, data, operation, txGasEstimate, gasToken, meta, refundAddress, signatureCount) => {
//         // numbers < 256 are 192 -> 31 * 4 + 68
//         // numbers < 65k are 256 -> 30 * 4 + 2 * 68
//         // For signature array length and dataGasEstimate we already calculated the 0 bytes so we just add 64 for each non-zero byte
//         let signatureCost = signatureCount * (68 + 2176 + 2176) // array count (3 -> r, s, v) * signature count
//         let payload = subscriptionModule.methods.execSubscription(
//             to, value, data, operation, txGasEstimate, 0, GAS_PRICE, gasToken, refundAddress, meta, "0x"
//         ).encodeABI();
//         let dataGasEstimate = utils.estimateDataGasCosts(payload) + signatureCost
//         if (dataGasEstimate > 65536) {
//             dataGasEstimate += 64
//         } else {
//             dataGasEstimate += 128
//         }
//         return dataGasEstimate + 32000; // Add aditional gas costs (e.g. base tx costs, transfer costs)
//     }
//
//     let executeSubscriptionWithSigner = async (signer, subject, accounts, to, value, data, operation, refundReceiver, opts) => {
//         let options = opts || {
//             fails: false,
//             meta: {
//                 oracle: web3.utils.fromAscii('ethusd'),
//                 period: 1,
//                 offChainID: 0,
//                 startDate: 0,
//                 endDate: 0
//             },
//             noExec: false,
//             gasToken: "0x0000000000000000000000000000000000000000"
//         };
//         let txFailed = options.fails;
//         let gasToken = options.gasToken || "0x0000000000000000000000000000000000000000";
//         let meta = await subscriptionModule.methods.getSubscriptionMetaBytes(
//             options.meta.oracle,
//             options.meta.period, //period
//             options.meta.offChainID, //offChainID
//             options.meta.startDate, //startDate
//             options.meta.endDate  //endDate
//         ).call()
//         // Estimate safe transaction (need to be called with from set to the safe address)
//
//         let txGasEstimate = 0;
//         try {
//             let estimateData = subscriptionModule.methods.requiredTxGas(to, value, data, operation, meta).encodeABI();
//             let estimateResponse = await web3.eth.call({
//                 to: subscriptionModule.options.address,
//                 from: subscriptionModule.options.address,
//                 data: estimateData
//             })
//             txGasEstimate = new BigNumber(estimateResponse.substring(138), 16).toNumber()
//             // Add 10k else we will fail in case of nested calls
//             txGasEstimate = txGasEstimate + 10000;
//             console.log("    Tx Gas estimate: " + txGasEstimate)
//         } catch (e) {
//             console.log("    Could not estimate " + subject)
//         }
//
//         let dataGasEstimate = estimateDataGas(to, value, data, operation, txGasEstimate, gasToken, meta, refundReceiver, accounts.length)
//         console.log("    Data Gas estimate: " + dataGasEstimate)
//
//         let gasPrice = GAS_PRICE
//         if (gasToken !== 0) {
//             gasPrice = 1
//         }
//
//
//         let sigs = await signer(accounts, to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, gasToken, refundReceiver, meta);
//
//         // Execute paying transaction
//         // We add the txGasEstimate and an additional 10k to the estimate to ensure that there is enough gas for the safe transaction
//
//         let tx = null;
//         if (!opts.noExec) {
//             tx = await subscriptionModule.methods.execSubscription(
//                 to,
//                 value,
//                 data,
//                 operation,
//                 txGasEstimate,
//                 dataGasEstimate,
//                 gasPrice,
//                 gasToken,
//                 refundReceiver,
//                 meta,
//                 sigs
//             ).send({
//                 from: refundReceiver,
//                 gas: 8000000
//             });
//             let events = await utils.checkTxEvent(tx, 'PaymentFailed', subscriptionModule, txFailed, subject)
//             if (txFailed) {
//                 let subHash = await subscriptionModule.methods.getSubscriptionHash(to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, gasToken, refundReceiver, meta)
//                 assert.equal(subHash, events.args.subHash)
//             }
//         }
//
//
//         return {
//             tx,
//             dataFields: {
//                 to,
//                 value,
//                 data,
//                 operation,
//                 txGasEstimate,
//                 dataGasEstimate,
//                 gasPrice,
//                 gasToken,
//                 refundReceiver,
//                 meta,
//                 sigs
//             }
//         }
//     }
//
//     beforeEach(async () => {
//
//
//         bulkExecutor = await getInstance("BulkExecutor", {create: true});
//
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
//             create: true, constructorArgs: PayingProxy.bytecode
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
//         // Subscription module setup
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
//         gnosisSafe = await utils.getParamFromTxEvent(
//             await proxyFactory.methods.createProxy(
//                 gnosisSafeMasterCopy.options.address,
//                 gnosisSafeData
//             ).send({from: accounts[0], gasLimit: 8000000}),
//             'ProxyCreation',
//             'proxy',
//             proxyFactory.options.address,
//             'GnosisSafe',
//             'create Gnosis Safe',
//             getInstance
//         );
//
//         merchantSafe = await utils.getParamFromTxEvent(
//             await proxyFactory.methods.createProxy(
//                 gnosisSafeMasterCopy.options.address,
//                 merchantSafeData
//             ).send({from: accounts[0], gasLimit: 8000000}),
//             'ProxyCreation',
//             'proxy',
//             proxyFactory.options.address,
//             'GnosisSafe',
//             'create Merchant Gnosis Safe',
//             getInstance
//         );
//
//
//         // gnosisSafe = await getInstance("GnosisSafe", {deployedAddress: '0x716F028c353e2790Fed210E68eB90e2572fC69DA'})
//
//         let modules = await gnosisSafe.methods.getModules().call()
//         subscriptionModule = await getInstance('SubscriptionModule', {deployedAddress: modules[0]})
//         assert.equal(await subscriptionModule.methods.manager().call(), gnosisSafe.options.address)
//
//         let merchantModules = await merchantSafe.methods.getModules().call()
//         merchantModule = await getInstance('merchantModule', {deployedAddress: merchantModules[0]})
//         assert.equal(await merchantModule.methods.manager().call(), merchantSafe.options.address)
//
//     })
//
//
//     it('should deposit 1.1 ETH, create a $50 USD subscription, and then cancel the subscription before it even gets activated with meta txn workflow', async () => {
//         // Deposit 1 ETH + some spare money for execution
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//         let confirmingAccounts = [accounts[0]];
//         let subSig = await signer(
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             executor,
//             await subscriptionModule.methods.getSubscriptionMetaBytes(web3.utils.fromAscii('ethusd'), 1, 1, 0, 0).call()
//         );
//
//         let gnosisSafeNonce = await gnosisSafe.methods.nonce().call();
//
//         let subscriptionHash = await subscriptionModule.methods.getSubscriptionHash(
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             executor,
//             await subscriptionModule.methods.getSubscriptionMetaBytes(web3.utils.fromAscii('ethusd'), 1, 1, 0, 0).call()
//         ).call();
//
//         let cancelSigs = await cancelSigner(
//             confirmingAccounts,
//             subscriptionHash
//         );
//
//         await subscriptionModule.methods.cancelSubscription(
//             subscriptionHash,
//             cancelSigs
//         ).send({from: accounts[0], gasLimit: 8000000});
//
//         await utils.shouldFailWithMessage(
//             subscriptionModule.methods.execSubscription(
//                 receiver,
//                 web3.utils.toWei('50', 'ether'),
//                 "0x",
//                 CALL,
//                 0,
//                 0,
//                 0,
//                 "0x0000000000000000000000000000000000000000",
//                 executor,
//                 await subscriptionModule.methods.getSubscriptionMetaBytes(web3.utils.fromAscii('ethusd'), 1, 1, 0, 0).call(),
//                 subSig
//             ).send({
//                 from: executor,
//                 gasLimit: 8000000
//             }),
//             "INVALID_STATE: SUB_STATUS"
//         );
//     });
//
//     it('generate a subscription hash, process it, and then cancel it as the recipient', async () => {
//         // assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//
//         let confirmingAccounts = [accounts[0]];
//
//
//         let resp1 = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 ETHUSD',
//             confirmingAccounts,
//             merchantModule.options.address,
//             web3.utils.toWei('0.005', 'ether'),
//             '0x',
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: 0, //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         );
//
//         let {
//             to,
//             value,
//             data,
//             operation,
//             txGasEstimate,
//             dataGasEstimate,
//             gasPrice,
//             gasToken,
//             refundReceiver,
//             meta,
//             sigs
//         } = resp1.dataFields
//
//         let merchantNonce = await merchantSafe.methods.nonce().call();
//
//         let cancelData = await merchantModule.methods.cancelCXSubscription(
//             subscriptionModule.options.address,
//             to,
//             value,
//             data,
//             operation,
//             txGasEstimate,
//             dataGasEstimate,
//             gasPrice,
//             gasToken,
//             refundReceiver,
//             meta,
//             sigs
//         ).encodeABI();
//
//         let merchantCXCancelSigs = await txSigner(
//             confirmingAccounts,
//             merchantModule.options.address,
//             0,
//             cancelData,
//             0,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             merchantNonce,
//             merchantSafe.options.address
//         );
//
//         let cancelTx = await merchantSafe.methods.execTransaction(
//             merchantModule.options.address,
//             0,
//             cancelData,
//             0,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             merchantCXCancelSigs
//         ).send({
//             from: accounts[0],
//             gasLimit: 8000000
//         })
//
//         await utils.shouldFailWithMessage(
//         executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 ETHUSD',
//             confirmingAccounts,
//             merchantModule.options.address,
//             web3.utils.toWei('0.005', 'ether'),
//             '0x',
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: 0, //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         ), "INVALID_STATE: SUB_STATUS");
//     })
//
//     it('generate x2 subscriptions(HOG Token, $50 ETHUSD), bulk execute/payment split', async () => {
//         // assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         // assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//
//         let hogToken = await getInstance("TestToken", {create: true, constructorArgs: [gnosisSafe.options.address]});
//
//         console.log(`Hog Token ${hogToken.options.address}`);
//
//
//         let txdata = hogToken.methods.transfer(merchantModule.options.address, web3.utils.toWei('1337', 'ether')).encodeABI();
//
//         let confirmingAccounts = [accounts[0]];
//
//         let customers = [],
//             to = [],
//             value = [],
//             data = [],
//             operation = [],
//             gasInfo = [], //0 txgas 1dataGas 2 gasPrice
//             gasToken = [],
//             refundReceiver = [],
//             metaSig = [];
//
//
//         let merchantBalanceETH = await web3.eth.getBalance(merchantSafe.options.address);
//         let merchantBalanceHOG = await hogToken.methods.balanceOf(merchantSafe.options.address).call();
//
//
//         let resp1 = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 ETHUSD',
//             confirmingAccounts,
//             hogToken.options.address,
//             0,
//             txdata,
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: 0, //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 },
//                 noExec: true
//             }
//         );
//
//         customers.push(subscriptionModule.options.address);
//         to.push(resp1.dataFields.to);
//         value.push(resp1.dataFields.value);
//         data.push(resp1.dataFields.data);
//         operation.push(resp1.dataFields.operation);
//         gasInfo.push([resp1.dataFields.txGasEstimate, resp1.dataFields.dataGasEstimate, resp1.dataFields.gasPrice]);
//         gasToken.push(resp1.dataFields.gasToken);
//         refundReceiver.push(resp1.dataFields.refundReceiver);
//         metaSig.push([resp1.dataFields.meta, resp1.dataFields.sigs]);
//
//         let resp2 = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 ETHUSD',
//             confirmingAccounts,
//             merchantModule.options.address,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1,
//                     offChainID: 2,
//                     startDate: 0,
//                     endDate: 0 //slot 5
//                 },
//                 noExec: true
//             }
//         );
//
//         customers.push(subscriptionModule.options.address);
//         to.push(resp2.dataFields.to);
//         value.push(resp2.dataFields.value);
//         data.push(resp2.dataFields.data);
//         operation.push(resp2.dataFields.operation);
//         gasInfo.push([resp2.dataFields.txGasEstimate, resp2.dataFields.dataGasEstimate, resp2.dataFields.gasPrice]);
//         gasToken.push(resp2.dataFields.gasToken);
//         refundReceiver.push(resp2.dataFields.refundReceiver);
//         metaSig.push([resp2.dataFields.meta, resp2.dataFields.sigs]);
//
//
//         //move blocktime forward just over a day by a few hours
//         await timeHelper.advanceTimeAndBlock(96400);
//
//         let bulk = await bulkExecutor.methods.execute(
//             customers,
//             to,
//             value,
//             data,
//             operation,
//             gasInfo, //0 txgas 1dataGas 2 gasPrice
//             gasToken,
//             refundReceiver,
//             metaSig
//         ).send({from: accounts[0], gasLimit: 8000000})
//
//
//         let aftermerchantBalanceETH = await web3.eth.getBalance(merchantSafe.options.address);
//         let aftermerchantBalanceHOG = await hogToken.methods.balanceOf(merchantSafe.options.address).call();
//
//
//         assert.ok((aftermerchantBalanceETH > merchantBalanceETH) && (aftermerchantBalanceHOG > merchantBalanceHOG));
//     })
//
//     it('should deposit 1.1 ETH, create a $50 USD subscription but fail to execute it through a re-entrancy contract that attempts to re enter execSubscription, stealing extra funds', async () => {
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//
//         let confirmingAccounts = [accounts[0], accounts[2]];
//         let subSig = await signer(
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('0.5', 'ether'),
//             "0x",
//             CALL,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             await subscriptionModule.methods.getSubscriptionMetaBytes(0, 1, 1, 0, 0).call()
//         );
//
//
//         let reEntrant = await getInstance("ReEntryAttacker", {
//             create: true,
//             constructorArgs: [subscriptionModule.options.address]
//         });
//
//         let balanceBeforeAttack = await web3.eth.getBalance(gnosisSafe.options.address);
//         let tx = await reEntrant.methods.attack(
//             receiver,
//             web3.utils.toWei('0.5', 'ether'),
//             "0x",
//             CALL,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             await subscriptionModule.methods.getSubscriptionMetaBytes(0, 1, 1, 0, 0).call(),
//             subSig
//         ).send({
//             from: executor,
//             gasLimit: 8000000
//         });
//
//         assert.equal(balanceBeforeAttack - web3.utils.toWei('0.5', 'ether'), await web3.eth.getBalance(gnosisSafe.options.address));
//
//     })
//     it('should deposit 2.0 ETH, create a $50 USD subscription, then upgrade to a $100 USD subscription, and fail on the retry of the original $50 USD subscription', async () => {
//         // Deposit 1 ETH
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: accounts[0],
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('2', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('2', 'ether'))
//
//
//         let tw = await getInstance("TransactionWrapper", {
//             localABI: [{
//                 "constant": false,
//                 "inputs": [
//                     {"name": "operation", "type": "uint8"},
//                     {"name": "to", "type": "address"},
//                     {"name": "value", "type": "uint256"},
//                     {"name": "data", "type": "bytes"}
//                 ],
//                 "name": "send",
//                 "outputs": [],
//                 "payable": false,
//                 "stateMutability": "nonpayable",
//                 "type": "function"
//             }]
//         });
//
//         let confirmingAccounts = [accounts[0], accounts[2]]
//
//         // Withdraw 0.5 ETH
//
//         let resp = await executeSubscriptionWithSigner(signer,
//             'executeSubscription withdraw $50 ETHUSD',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             })
//
//         let {
//             tx, dataFields
//         } = resp;
//
//         let {
//             to,
//             value,
//             data,
//             operation,
//             txGasEstimate,
//             dataGasEstimate,
//             gasPrice,
//             gasToken,
//             meta
//         } = dataFields;
//
//         let walletBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address);
//
//         console.log(`    Wallet Balance before Cancel and OTP ${web3.utils.fromWei(walletBalanceAfter.toString(), 'ether')} ETH`);
//         let subHash = await subscriptionModule.methods.getSubscriptionHash(to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, gasToken, executor, meta).call()
//         let doubleSigs = await signer(
//             confirmingAccounts,
//             to,
//             (value * 2).toString(),
//             data,
//             operation,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             meta
//         )
//
//         let subhashDoubleData = await subscriptionModule.methods.execSubscription(
//             to,
//             (value * 2).toString(),
//             data,
//             operation,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             meta,
//             doubleSigs
//         ).encodeABI();
//
//         let cancelData = subscriptionModule.methods.cancelSubscriptionAsManager(
//             subHash
//         ).encodeABI();
//
//         let gnosisSafeNonceSecond = (await gnosisSafe.methods.nonce().call()) + 1;
//
//         let safeCancelTxDataSigs = await txSigner(
//             confirmingAccounts,
//             subscriptionModule.options.address,
//             0,
//             cancelData,
//             0,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             gnosisSafeNonceSecond
//         );
//
//         let safeCancelTxData = await gnosisSafe.methods.execTransaction(
//             subscriptionModule.options.address,
//             0,
//             cancelData,
//             0,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             safeCancelTxDataSigs
//         ).encodeABI();
//
//
//         let otp = web3.utils.toWei('0.1', 'ether');
//
//         let nestedTransactionData = '0x' +
//             tw.methods.send(
//                 0,
//                 gnosisSafe.options.address,
//                 0,
//                 safeCancelTxData
//             ).encodeABI().substr(10) +
//             tw.methods.send(
//                 0,
//                 receiver,
//                 otp,
//                 "0x"
//             ).encodeABI().substr(10) +
//             tw.methods.send(
//                 0,
//                 subscriptionModule.options.address,
//                 0,
//                 subhashDoubleData
//             ).encodeABI().substr(10);
//
//         let multidata = await multiSend.methods.multiSend(
//             nestedTransactionData
//         ).encodeABI();
//
//         let gnosisSafeNonce = await gnosisSafe.methods.nonce().call();
//
//         let multiSendSigs = await txSigner(
//             confirmingAccounts,
//             multiSend.options.address,
//             0,
//             multidata,
//             DELEGATECALL,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             gnosisSafeNonce
//         );
//
//         let multitx = await gnosisSafe.methods.execTransaction(
//             multiSend.options.address,
//             0,
//             multidata,
//             DELEGATECALL,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             multiSendSigs
//         ).send({from: accounts[0], gasLimit: 8000000});
//
//         utils.logGasUsage(
//             'execTransaction send multiple transactions',
//             multitx
//         )
//
//         walletBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address)
//         console.log(`    Wallet Balance after Cancel and OTP ${web3.utils.fromWei(walletBalanceAfter.toString(), 'ether')} ETH`);
//
//         await utils.shouldFailWithMessage(
//             executeSubscriptionWithSigner(
//                 signer,
//                 'executeSubscription attempt withdraw $50 ETHUSD',
//                 confirmingAccounts,
//                 receiver,
//                 web3.utils.toWei('50', 'ether'),
//                 "0x",
//                 CALL,
//                 executor,
//                 {
//                     meta: {
//                         oracle: web3.utils.fromAscii('ethusd'), //oracle
//                         period: 1, //period
//                         offChainID: 1, //
//                         startDate: 0,
//                         endDate: 0
//                     }
//                 }),
//             "INVALID_STATE: SUB_STATUS"
//         )
//     });
//
//     it('should deposit 1.1 ETH and pay a daily 0.5 ETH subscription on two different days', async () => {
//         // Deposit 1 ETH + some spare money for execution
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//         let executorBalance = await web3.eth.getBalance(executor)
//         let recieverBalance = await web3.eth.getBalance(receiver)
//         let confirmingAccounts = [accounts[0], accounts[2]]
//
//
//         // Withdraw 0.5 ETH
//         let resp = await executeSubscriptionWithSigner(signer,
//             'executeSubscription withdraw 0.5 ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('0.5', 'ether'), //ether = usd or base pair
//             "0x", CALL, executor, {
//                 meta: {
//                     oracle: 0, //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             })
//
//         let {
//             tx,
//             dataFields
//         } = resp;
//
//         console.log(`    Paying Daily Subscription Tx 0.5 ETH: ${tx.transactionHash}`);
//
//         let safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address);
//         console.log(`    Wallet Balance After: ${web3.utils.fromWei(safeBalanceAfter.toString(), 'ether')} ETH`);
//
//         let executorDiff = executorBalance - await web3.eth.getBalance(executor);
//         console.log(`    Executor earned ${web3.utils.fromWei(executorDiff.toString(), 'ether')} ETH`);
//
//         executorBalance = await web3.eth.getBalance(executor);
//
//         console.log(`    Advancing Time 86400 seconds (1 Day)`);
//         await timeHelper.advanceTimeAndBlock(86400);
//
//         resp = await executeSubscriptionWithSigner(signer,
//             'executeSubscription withdraw 0.5 ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('0.5', 'ether'),
//             "0x", CALL, executor,
//             {
//                 meta: {
//                     oracle: 0, //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         )
//
//         let tx2 = resp.tx;
//
//         console.log(`    Paying Daily Subscription Tx 0.5 ETH: ${tx2.transactionHash}`);
//         safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address)
//
//         console.log(`    Wallet Balance After: ${web3.utils.fromWei(safeBalanceAfter.toString(), 'ether')} ETH`);
//
//         executorDiff = executorBalance - await web3.eth.getBalance(executor);
//
//
//         let receiverDiff = await web3.eth.getBalance(receiver) - recieverBalance
//         console.log(`    Executor earned ${web3.utils.fromWei(executorDiff.toString(), 'ether')} ETH`);
//
//         console.log(`    Receiver Difference: ${web3.utils.fromWei(receiverDiff.toString(), 'ether')} ETH`);
//
//         assert.equal(receiverDiff, web3.utils.toWei('1', 'ether'))
//     });
//
//     it('should deposit 1.1 ETH and pay a daily subscription of 50 USD, on two different days', async () => {
//         // Deposit 1 ETH + some spare money for execution
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//         let executorBalance = await web3.eth.getBalance(executor)
//         let receiverBalance = await web3.eth.getBalance(receiver)
//         let confirmingAccounts = [accounts[0], accounts[2]]
//
//
//         // Withdraw 50 USD in ETH
//         let resp = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 USD of ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         )
//
//         let {
//             tx, dataFields
//         } = resp;
//
//         console.log(`    Paying Daily Subscription Tx 50 USD : ${tx.transactionHash}`);
//         let executorDiff;
//         let receiverDiff;
//         let safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address);
//         console.log(`    Wallet Balance After: ${web3.utils.fromWei(safeBalanceAfter.toString(), 'ether')} ETH`);
//         executorDiff = executorBalance - await web3.eth.getBalance(executor);
//         executorBalance = await web3.eth.getBalance(executor);
//         console.log("    Executor earned " + web3.utils.fromWei(executorDiff.toString(), 'ether') + " ETH");
//
//         console.log(`    Advancing Time 86400 seconds (1 Day)`);
//         await timeHelper.advanceTimeAndBlock(86400);
//
//         resp = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 USD of ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         )
//
//         let tx2 = resp.tx;
//
//         console.log(`    Paying Daily Subscription Tx 50 USD: ${tx2.transactionHash}`);
//         safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address)
//         console.log(`    Wallet Balance After: ${web3.utils.fromWei(safeBalanceAfter.toString(), 'ether')}`);
//         executorDiff = executorBalance - await web3.eth.getBalance(executor);
//
//         receiverDiff = await web3.eth.getBalance(receiver) - receiverBalance;
//         console.log("    Executor earned " + web3.utils.fromWei(executorDiff.toString(), 'ether') + " ETH");
//
//         console.log(`    Receiver difference: ${web3.utils.fromWei(receiverDiff.toString(), 'ether')} ETH`);
//
//
//         assert.ok(receiverDiff > 0);
//     });
//
//     it('Deposit 1.1 ETH, Charge $50 USD Subscription(Day1), Upgrade SubscriptionModule, Advance 1 Time Day, Charge $50 USD Subscription(Day2)', async () => {
//         // Deposit 1 ETH + some spare money for execution
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//         let executorBalance = await web3.eth.getBalance(executor);
//         let receiverBalance = await web3.eth.getBalance(receiver);
//         let confirmingAccounts = [accounts[0], accounts[2]];
//
//
//         // Withdraw 50 USD in ETH
//         let resp = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 USD of ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         )
//
//
//         await timeHelper.advanceTimeAndBlock(86400);
//
//
//         let masterCopyChangeData = await masterCopy.methods.changeMasterCopy(mc2.options.address).encodeABI();
//         let safeNonce = await gnosisSafe.methods.nonce().call();
//         let masterCopyChangeSigs = await txSigner(
//             confirmingAccounts,
//             subscriptionModule.options.address,
//             0,
//             masterCopyChangeData,
//             0,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             safeNonce
//         )
//
//         let changeTx = await gnosisSafe.methods.execTransaction(
//             subscriptionModule.options.address,
//             0,
//             masterCopyChangeData,
//             0,
//             0,
//             0,
//             0,
//             "0x0000000000000000000000000000000000000000",
//             "0x0000000000000000000000000000000000000000",
//             masterCopyChangeSigs
//         ).send({
//             from: executor,
//             gasLimit: 8000000
//         })
//
//         let resp2 = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 USD of ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         )
//
//         console.log(`    Changing from SubscriptionModuleV1 -> SubscriptionModuleV2 Txn: ${resp2.tx.transactionHash}`);
//         let smc = await getInstance("MasterCopy", {deployedAddress: subscriptionModule.options.address});
//         assert.equal(await web3.eth.getStorageAt(smc.options.address.toLowerCase(), 0), mc2.options.address.toLowerCase());
//     });
//
//     it('should deposit 1.1 ETH and attempt to pay a daily subscription of 50 USD twice on the same day', async () => {
//         // Deposit 1 ETH + some spare money for execution
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
//         await web3.eth.sendTransaction({
//             from: receiver,
//             to: gnosisSafe.options.address,
//             value: web3.utils.toWei('1.1', 'ether')
//         })
//         assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), web3.utils.toWei('1.1', 'ether'))
//
//         let executorBalance = await web3.eth.getBalance(executor)
//         let receiverBalance = await web3.eth.getBalance(receiver)
//         let confirmingAccounts = [accounts[0], accounts[2]]
//
//
//         // Withdraw 50 USD in ETH
//         let resp = await executeSubscriptionWithSigner(
//             signer,
//             'executeSubscription withdraw $50 USD of ETH',
//             confirmingAccounts,
//             receiver,
//             web3.utils.toWei('50', 'ether'),
//             "0x",
//             CALL,
//             executor,
//             {
//                 meta: {
//                     oracle: web3.utils.fromAscii('ethusd'), //oracle
//                     period: 1, //period
//                     offChainID: 1, //
//                     startDate: 0,
//                     endDate: 0
//                 }
//             }
//         )
//
//         let {
//             tx, dataFields
//         } = resp;
//
//         console.log(`    Paying Daily Subscription Tx 50 USD : ${tx.transactionHash}`);
//         let executorDiff;
//         let receiverDiff;
//         let safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address);
//         console.log(`    Wallet Balance After: ${web3.utils.fromWei(safeBalanceAfter.toString(), 'ether')} ETH`);
//         executorDiff = executorBalance - await web3.eth.getBalance(executor);
//         executorBalance = await web3.eth.getBalance(executor);
//         console.log("    Executor earned " + web3.utils.fromWei(executorDiff.toString(), 'ether') + " ETH");
//
//         await utils.shouldFailWithMessage(
//             executeSubscriptionWithSigner(
//                 signer,
//                 'executeSubscription withdraw $50 USD of ETH',
//                 confirmingAccounts,
//                 receiver,
//                 web3.utils.toWei('50', 'ether'),
//                 "0x",
//                 CALL,
//                 executor,
//                 {
//                     failed: true,
//                     meta: {
//                         oracle: web3.utils.fromAscii('ethusd'), //oracle
//                         period: 1, //period
//                         offChainID: 1, //
//                         startDate: 0,
//                         endDate: 0
//                     }
//                 }
//             ), "INVALID_STATE: SUB_NEXT_WITHDRAW");
//
//         let tx2 = resp.tx;
//
//         console.log(`    Failing 2nd Transaction to Pay Subscription Tx 50 USD: ${tx2.transactionHash}`);
//         safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address)
//         console.log(`    Wallet Balance After: ${web3.utils.fromWei(safeBalanceAfter.toString(), 'ether')}`);
//         executorDiff = executorBalance - await web3.eth.getBalance(executor);
//
//         receiverDiff = await web3.eth.getBalance(receiver) - receiverBalance;
//         console.log(`    Executor earned ${web3.utils.fromWei(executorDiff.toString(), 'ether')} ETH`);
//
//         console.log(`    Receiver difference: ${web3.utils.fromWei(receiverDiff.toString(), 'ether')} ETH`);
//
//
//         assert.ok(receiverDiff > 0);
//     });
// })
//
