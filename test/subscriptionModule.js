
const utils = require('./utils')
const BigNumber = require('bignumber.js')
const timeHelper = require('./time')
const fs = require('fs')
const CreateAndAddModules = artifacts.require("./libraries/CreateAndAddModules.sol");
const GnosisSafe = artifacts.require("./GnosisSafe.sol")
const SubscriptionModule = artifacts.require("./modules/SubscriptionModule.sol")
const ProxyFactory = artifacts.require("./ProxyFactory.sol")
const ModuleDataWrapper = artifacts.require("./ModuleDataWrapper.sol")
const PayingProxy = artifacts.require("./PayingProxy.sol")
const Proxy = artifacts.require("./Proxy.sol")


const { getWeb3, getContractInstance } = require("./helpers")
// const web3 = getWeb3()
const getInstance = getContractInstance(web3)

const GAS_PRICE = web3.utils.toWei('20', 'gwei')

contract('SubscriptionModule', function (accounts) {
    // const payingProxyJson = JSON.parse(fs.readFileSync("./build/contracts/PayingProxy.json"))
    // const PayingProxy = web3.eth.Contract(payingProxyJson.abi)

    let gnosisSafe;
    let subscriptionModule;
    let lw;
    let executor = accounts[8];
    let receiver = accounts[9];

    const CALL = 0;

    let signTypedData = async function (account, data) {
        return new Promise(function (resolve, reject) {
            web3.currentProvider.sendAsync({
                method: "eth_signTypedData",
                params: [account, data],
                from: account
            }, function (err, response) {
                if (err) {
                    return reject(err);
                }
                resolve(response.result);
            });
        });
    }

    let signer = async function (confirmingAccounts, to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, txGasToken, refundAddress, meta) {
        let typedData = {
            types: {
                EIP712Domain: [
                    {type: "address", name: "verifyingContract"}
                ],
                // "SafeSubTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,uint256 gasPrice,address gasToken, address refundAddress, bytes meta)"
                SafeSubTx: [
                    {type: "address", name: "to"},
                    {type: "uint256", name: "value"},
                    {type: "bytes", name: "data"},
                    {type: "uint8", name: "operation"},
                    {type: "uint256", name: "safeTxGas"},
                    {type: "uint256", name: "dataGas"},
                    {type: "uint256", name: "gasPrice"},
                    {type: "address", name: "gasToken"},
                    {type: "address", name: "refundAddress"},
                    {type: "bytes", name: "meta"},
                ]
            },
            domain: {
                verifyingContract: subscriptionModule.options.address
            },
            primaryType: "SafeSubTx",
            message: {
                to: to,
                value: value,
                data: data,
                operation: operation,
                safeTxGas: txGasEstimate,
                dataGas: dataGasEstimate,
                gasPrice: gasPrice,
                gasToken: txGasToken,
                refundAddress: refundAddress,
                meta: meta
            }
        };

        let signatureBytes = "0x"
        confirmingAccounts.sort();
        for (var i = 0; i < confirmingAccounts.length; i++) {
            signatureBytes += (await signTypedData(confirmingAccounts[i], typedData)).replace('0x', '')
        }
        return signatureBytes
    }


    let estimateDataGas = function (to, value, data, operation, txGasEstimate, gasToken, meta, refundAddress, signatureCount) {
        // numbers < 256 are 192 -> 31 * 4 + 68
        // numbers < 65k are 256 -> 30 * 4 + 2 * 68
        // For signature array length and dataGasEstimate we already calculated the 0 bytes so we just add 64 for each non-zero byte
        let signatureCost = signatureCount * (68 + 2176 + 2176) // array count (3 -> r, s, v) * signature count
        let payload = subscriptionModule.contract.execSubscription(
            to, value, data, operation, txGasEstimate, 0, GAS_PRICE, gasToken, refundAddress, meta, "0x"
        ).encodeABI();
        let dataGasEstimate = utils.estimateDataGasCosts(payload) + signatureCost
        if (dataGasEstimate > 65536) {
            dataGasEstimate += 64
        } else {
            dataGasEstimate += 128
        }
        return dataGasEstimate + 32000; // Add aditional gas costs (e.g. base tx costs, transfer costs)
    }

    let executeSubscriptionWithSigner = async function (signer, subject, accounts, to, value, data, operation, executor, opts) {
        let options = opts || {};
        let txFailed = options.fails || false;
        let txGasToken = options.gasToken || 0;
        let meta = options.meta || await subscriptionModule.contract.getSubscriptionMetaBytes(1, 1, 0)
        // Estimate safe transaction (need to be called with from set to the safe address)
        //meta = meta.toHex();

        let txGasEstimate = 0
        // let manager = await subscriptionModule.contract.manager();
        try {
            // let subhash = await subscriptionModule.contract.getSubscriptionHash(to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, txGasToken, executor, meta);
            let estimateData = subscriptionModule.contract.requiredTxGas(to, value, data, operation, meta).encodeABI();
            let estimateResponse = await web3.eth.call({to: subscriptionModule.options.address, from: gnosisSafe.options.address, data: estimateData})
            txGasEstimate = new BigNumber(estimateResponse.substring(138), 16).toNumber()
            // Add 10k else we will fail in case of nested calls
            txGasEstimate = txGasEstimate + 90000
            console.log("    Tx Gas estimate: " + txGasEstimate)
        } catch (e) {
            console.log("    Could not estimate " + subject)
        }

        let dataGasEstimate = estimateDataGas(to, value, data, operation, txGasEstimate, txGasToken, meta, executor, accounts.length)
        console.log("    Data Gas estimate: " + dataGasEstimate)

        let gasPrice = GAS_PRICE
        if (txGasToken !== 0) {
            gasPrice = 1
        }



        let sigs = await signer(accounts, to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, txGasToken, executor, meta);
        // console.log(`groundhog: ${gnosisSafe.options.address}`);
        // console.log(`groundhog: ${subscriptionModule.options.address}`);
        // console.log(`to: ${to}`);
        // console.log(`value: ${value}`);
        // console.log(`data: ${data}`);
        // console.log(`operation: ${operation}`);
        // console.log(`txgases: ${txGasEstimate}`);
        // console.log(`datagasestimate: ${dataGasEstimate}`);
        // console.log(`gasprice: ${gasPrice}`);
        // console.log(`gastoken: ${txGasToken}`);
        // console.log(`refund: ${executor}`);
        // console.log(`meta: ${meta}`);
        // console.log(`Sigs: ${sigs}`)

        let safeBalanceBefore = await web3.eth.getBalance(gnosisSafe.options.address).toNumber();
        console.log(`    Balance Before: ${safeBalanceBefore}`)

        // Execute paying transaction
        // We add the txGasEstimate and an additional 10k to the estimate to ensure that there is enough gas for the safe transaction
        let tx = subscriptionModule.execSubscription(
            to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, txGasToken, executor, meta, sigs, {from: executor, gas:8000000}
        );

        // let events = utils.checkTxEvent(tx, 'PaymentFailed', subscriptionModule.options.address, txFailed, subject)
        // if (txFailed) {
        //     let subHash = await subscriptionModule.getSubscriptionHash(accounts, to, value, data, operation, txGasEstimate, dataGasEstimate, gasPrice, txGasToken, executor, meta)
        //     assert.equal(subHash, events.args.subHash)
        // }
        return tx;
    }

    beforeEach(async function () {
        // Create lightwallet
        // lw = await utils.createLightwallet()
        // Create libraries
        // Create Master Copies

        // let createAndAddModules = getInstance("CreateAndAddModules");
        // let proxyFactory = getInstance("ProxyFactory");
        // let gnosisSafeMasterCopy = getInstance("GnosisSafe");
        // let subscriptionModuleMasterCopy = getInstance("SubscriptionModule");
        // let mdw = getInstance("ModuleDataWrapper");
        // let mdw = await ModuleDataWrapper.new()
        //setup master copies
        let createAndAddModules = await CreateAndAddModules.new()
        let proxyFactory = await ProxyFactory.new(Proxy.bytecode)
        let gnosisSafeMasterCopy = await GnosisSafe.new()
        let subscriptionModuleMasterCopy = await SubscriptionModule.new()
        gnosisSafeMasterCopy.setup([accounts[0], accounts[1], accounts[2]], 2, 0, "0x")
        subscriptionModuleMasterCopy.setup()
        // proxyFactory.setup(Proxy)
        // let proxyFactory = ProxyFactory.at('0xc48c777a072f3e0e4429f2d419379e60daed4924')
        // let gnosisSafeMasterCopy = GnosisSafe.at('0x155be870022842b7C3B9097eCEd5a7a92003a149')
        // let subscriptionModuleMasterCopy = SubscriptionModule.at('0x0755ac5de64e0819a4e2c10fce281dc82cee3e7d')
        // let createAndAddModules = CreateAndAddModules.at('0x8f5071ee235f4ddd972491b6ceaeeba5e4263202')

        // Subscription module setup
        let subscriptionModuleSetupData = await subscriptionModuleMasterCopy.contract.setup.getData();
        let subscriptionModuleCreationData = await proxyFactory.contract.createProxy.getData(subscriptionModuleMasterCopy.options.address, subscriptionModuleSetupData);

        // let modulesCreationData = utils.createAndAddModulesData([subscriptionModuleCreationData])
        let modulesCreationData = [subscriptionModuleCreationData].reduce((acc, data) => acc + mdw.contract.setup.getData(data).substr(74), "0x")
        //called as apart of the setup, currently doesn't work when initialized through the constructor paying proxy workflow
        let createAndAddModulesData = createAndAddModules.contract.createAndAddModules.getData(proxyFactory.options.address, modulesCreationData )
        // Create Gnosis Safe
        let gnosisSafeData = await gnosisSafeMasterCopy.contract.setup.getData([accounts[0], accounts[1], accounts[2]], 1, createAndAddModules.options.address, createAndAddModulesData);

        // gnosisSafe = utils.getParamFromTxEvent(
        //     await proxyFactory.contract.createProxy(
        //         gnosisSafeMasterCopy.options.address,
        //         gnosisSafeData,
        //     ),
        //     'ProxyCreation', 'proxy', proxyFactory.options.address, GnosisSafe, 'create Gnosis Safe',
        // )

        gnosisSafe = await proxyFactory.createPayingProxy(
            54,
            gnosisSafeMasterCopy.options.address,
            gnosisSafeData,
            gnosisSafeMasterCopy.options.address,
            gnosisSafeMasterCopy.options.address,
            0
        )

        let modules = await gnosisSafe.contract.getModules()
        subscriptionModule = new SubscriptionModule(modules[0]);
        assert.equal(await subscriptionModule.manager.call(), gnosisSafe.options.address)
    })

    it('should deposit 1.1 ETH and pay a daily 0.5 ETH subscription on two different days', async () => {
        // Deposit 1 ETH + some spare money for execution
        assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
        await web3.eth.sendTransaction({from: receiver, to: gnosisSafe.options.address, value: web3.utils.toWei('1.1', 'ether')})
        assert.equal(await web3.eth.getBalance(gnosisSafe.options.address).toNumber(), web3.utils.toWei('1.1', 'ether'))

        let executorBalance = await web3.eth.getBalance(executor).toNumber()
        let recieverBalance = await web3.eth.getBalance(receiver).toNumber()
        let confirmingAccounts = [accounts[0], accounts[2]]


        // Withdraw 0.5 ETH
        let tx = await executeSubscriptionWithSigner(signer, 'executeSubscription withdraw 0.5 ETH', confirmingAccounts, receiver, web3.utils.toWei('0.5', 'ether'), "0x", CALL, executor, {meta: await subscriptionModule.contract.getSubscriptionMetaBytes(1, 1, 0)})


        console.log(`    Paying Daily Subscription Tx 0.5 ETH: ${tx}`);

        let safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address).toNumber();
        console.log(`    Balance After: ${safeBalanceAfter}`);
        let executorDiff = await web3.eth.getBalance(executor) - executorBalance
        executorBalance = await web3.eth.getBalance(executor);
        console.log("    Executor earned " + web3.fromWei(executorDiff, 'ether') + " ETH");

        console.log(`    Advancing Time 86400 seconds (1 Day)`);
        await timeHelper.advanceTimeAndBlock(86400);

        let tx2 = await executeSubscriptionWithSigner(signer, 'executeSubscription withdraw 0.5 ETH', confirmingAccounts, receiver, web3.utils.toWei('0.5', 'ether'), "0x", CALL, executor, {meta: await subscriptionModule.contract.getSubscriptionMetaBytes(1, 1, 0)})

        console.log(`    Paying Daily Subscription Tx 0.5 ETH: ${tx2}`);
        safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address).toNumber();
        console.log(`    After: ${safeBalanceAfter}`);
        executorDiff = await web3.eth.getBalance(executor) - executorBalance;

        let receiverDiff = await web3.eth.getBalance(receiver) - recieverBalance
        console.log("    Executor earned " + web3.fromWei(executorDiff, 'ether') + " ETH");

        assert.equal(receiverDiff, web3.utils.toWei('1', 'ether'))
    });

    // it('should deposit 1.1 ETH attempt to pay the same 0.5 subscription twice in the same day', async () => {
    //     // Deposit 1 ETH + some spare money for execution
    //     assert.equal(await web3.eth.getBalance(gnosisSafe.options.address), 0)
    //     await web3.eth.sendTransaction({from: receiver, to: gnosisSafe.options.address, value: web3.utils.toWei('1.1', 'ether')})
    //     assert.equal(await web3.eth.getBalance(gnosisSafe.options.address).toNumber(), web3.utils.toWei('1.1', 'ether'))
    //
    //     let executorBalance = await web3.eth.getBalance(executor).toNumber()
    //     let recieverBalance = await web3.eth.getBalance(receiver).toNumber()
    //     let confirmingAccounts = [accounts[0], accounts[2]]
    //
    //
    //     // Withdraw 0.5 ETH
    //     let tx = await executeSubscriptionWithSigner(signer, 'executeSubscription withdraw 0.5 ETH', confirmingAccounts, receiver, web3.utils.toWei('0.5', 'ether'), "0x", CALL, executor, {meta: await subscriptionModule.contract.getSubscriptionMetaBytes(1, 1, 0)})
    //
    //
    //     console.log(`    Paying Daily Subscription Tx 0.5 ETH: ${tx}`);
    //
    //     let safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address).toNumber();
    //     console.log(`    Balance After: ${safeBalanceAfter}`);
    //
    //     console.log(`    Requesting Another Payment Immediately`);
    //
    //     await utils.assertRejects(
    //         executeSubscriptionWithSigner(signer, 'executeSubscription withdraw 0.5 ETH', confirmingAccounts, receiver, web3.utils.toWei('0.5', 'ether'), "0x", CALL, executor, {fails: true, meta: await subscriptionModule.contract.getSubscriptionMetaBytes(1, 1, 0)}),
    //         "Withdraw Cooldown"
    //     )
    //
    //
    //     // console.log(`    Paying Daily Subscription Tx 0.5 ETH: ${tx2}`);
    //     safeBalanceAfter = await web3.eth.getBalance(gnosisSafe.options.address).toNumber();
    //     console.log(`    After: ${safeBalanceAfter}`);
    //     let executorDiff = await web3.eth.getBalance(executor) - executorBalance
    //     let receiverDiff = await web3.eth.getBalance(receiver) - recieverBalance
    //
    //     console.log("    Executor earned " + web3.fromWei(executorDiff, 'ether') + " ETH");
    //
    //     assert.equal(receiverDiff, web3.utils.toWei('0.5', 'ether'));
    //
    // });
})

