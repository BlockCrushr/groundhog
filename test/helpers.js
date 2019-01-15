const Web3 = require("web3") // import web3 v1.0 constructor

// use globally injected web3 to find the currentProvider and wrap with web3 v1.0
const getWeb3 = () => {
    const myWeb3 = new Web3(web3.currentProvider)
    return myWeb3
}

// assumes passed-in web3 is v1.0 and creates a function to receive contract name
const getContractInstance = (web3) => async (contractName, opts) => {
    const artifact = artifacts.require(contractName) // globally injected artifacts helper
    let deployedAddress = null;
    let instance = null;
    let newArtifact = null;
    opts = opts || {
        create: false,
        constructorArgs: null,
        deployLookup: false,
        deployedAddress: null,
    };

    if (opts.deployedAddress) {
        instance = new web3.eth.Contract(artifact.abi, opts.deployedAddress);
    } else if (opts.deployLookup) {
        instance = new web3.eth.Contract(artifact.abi, artifact.networks[artifact.network_id].address);
    } else if (opts.create) {
        if (opts.constructorArgs) {
            if (opts.constructorArgs.length === 1) {
                newArtifact = await artifact.new(opts.constructorArgs[0]);
            } else {
                newArtifact = await artifact.new(opts.constructorArgs);
            }
        } else {
            newArtifact = await artifact.new();
        }
        instance = new web3.eth.Contract(artifact.abi, newArtifact.address);
    }


    return instance;
}
//
// // assumes passed-in web3 is v1.0 and creates a function to receive contract name
// const getNewContractInstance = (web3) => async (contractName, deployArgs = []) => {
//     const artifact = artifacts.require(contractName) // globally injected artifacts helper
//     let newArtifact = null;
//     if (deployArgs.length === 1) {
//         newArtifact = await artifact.new(deployArgs[0]);
//     } else {
//         newArtifact = await artifact.new(deployArgs);
//     }
//     const instance = new web3.eth.Contract(artifact.abi, newArtifact.address)
//     return instance
// }


module.exports = {getWeb3, getContractInstance: getContractInstance}