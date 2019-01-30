const Web3 = require("web3") // import web3 v1.0 constructor

const getWeb3 = () => {
    const myWeb3 = new Web3(web3.currentProvider)
    return myWeb3
}

const getContractInstance = (web3) => async (contractName, opts) => {
    opts = opts || {
        localABI: null,
        create: false,
        constructorArgs: null,
        deployLookup: false,
        deployedAddress: null,
    };

    if (opts.localABI) {
        return new web3.eth.Contract(opts.localABI, "0x72fE0d6A3E4CB16918A1c658f0856f3D9c64e3d4");
    }

    const artifact = artifacts.require(contractName);

    let instance = null;
    let newArtifact = null;

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

const create2Address = (creatorAddress, saltHex, byteCode) => {
    return `0x${web3.utils.sha3(`0x${[
        'ff',
        creatorAddress,
        saltHex,
        web3.utils.sha3(byteCode)
    ].map(x => x.replace(/0x/, ''))
        .join('')}`).slice(-40)}`.toLowerCase()
}

// converts an int to uint256
const numberToUint256 = (value) => {
    const hex = value.toString(16)
    return `0x${'0'.repeat(64 - hex.length)}${hex}`
}

// encodes parameter to pass as contract argument
const encodeParam = (dataType, data) => {
    return web3.eth.abi.encodeParameter(dataType, data)
}

// returns true if contract is deployed on-chain
const isContract = async (address) => {
    const code = await web3.eth.getCode(address)
    return code.slice(2).length > 0
}

const getStorageAt = async (address, slot = 0) => {
    const storage = await web3.eth.getStoragetAt(address, slot)
    return storage;
}

module.exports = {
    getWeb3,
    getStorageAt,
    isContract,
    encodeParam,
    getContractInstance: getContractInstance,
    create2Address: create2Address,
    num2uint: numberToUint256
}
