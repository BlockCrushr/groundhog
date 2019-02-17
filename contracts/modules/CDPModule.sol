pragma solidity ^0.5.0;

import "../base/Module.sol";
import "../common/SignatureDecoder.sol";
import "../base/OwnerManager.sol";


interface Tub {
    function safe(bytes32) external returns (bool);
}

interface Sai {
    function balanceOf(address) external returns (uint256);
}

contract CDPModule is Module, SignatureDecoder {


    address sai;
    address payable tub;

    bytes32 public domainSeparator;
    //keccak256(
    //    "EIP712Domain(address verifyingContract)"
    //);
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;

    //keccak256(
    //  "TopUpTx(uint256 cdp, uint256 maxTop)"
    //)
    bytes32 public constant CDP_TOP_TX_TYPEHASH = 0x4494907805e3ceba396741b2837174bdf548ec2cbe03f5448d7fa8f6b1aaf98e;

    /// @dev called during creation
    function setup(
        address payable[] memory mkrContracts
    )
    public
    {

        //set relevant mkr contracts as variables
        setManager();

        require(
            domainSeparator == 0,
            "SubscriptionModule::setup: INVALID_STATE: DOMAIN_SEPARATOR_SET"
        );

        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                address(this)
            )
        );

        require(
            sai == address(0),
            "CDPModule::setup: INVALID_STATE: SAI_SET"
        );

        sai = mkrContracts[0];

        require(
            tub == address(0),
            "CDPModule::setup: INVALID_STATE: TUB_SET"
        );

        tub = mkrContracts[1];

    }

    //check for the health of the cdp
    //likely hood of liquidation in the next x blocks
    //top up cdp with minimum threshold set


    function encodeTopUpHash(
        bytes32 cup,
        uint256 maxWad,
        uint256 threshold,
        Enum.Operation operation
    )
    internal
    returns (bytes memory)
    {
        bytes32 cdpTopHash = keccak256(
            abi.encode(
                CDP_TOP_TX_TYPEHASH,
                cup,
                maxWad,
                threshold,
                operation
            )
        );

        return abi.encodePacked(
            byte(0x19),
            byte(0x01),
            domainSeparator,
            cdpTopHash
        );
    }


    function executeTopUp(
        bytes32 cup,
        uint256 maxWad,
        uint256 threshold,
        Enum.Operation operation,
        bytes memory signatures,
        uint256 wad,
        address wadToken
    )
    public
    {
        bytes memory topHashData = encodeTopUpHash(
            cup,
            maxWad,
            threshold,
            operation
        );

        require(
            _checkHash(
                keccak256(topHashData),
                signatures
            ),
            "CDPModule::topUp: INVALID_DATA: SIGNATURES"
        );

        _topUp(
            cup,
            maxWad,
            wad,
            wadToken,
            operation
        );
    }


    function _topUp(
        bytes32 cup,
        uint256 maxWad,
        uint256 wad,
        address wadToken,
        Enum.Operation operation
    )
    internal
    {
        require(
            !Tub(tub).safe(cup),
            "CDPModule::topUp: INVALID_STATE: CDP_NO_RISK"
        );

        // TODO:   get cdp from cdp registry
        uint256 value = uint256(0);
        //determine how we're paying for the cost in USD, ether, tokens, kyber? otc via airswap?


        bool useSai = true;

        if (Sai(sai).balanceOf(address(manager)) <= wad || wadToken != address(0)) {
            //determine what we're going to do, are we converting through some exchange or using eth we own
            useSai = false;
        }

        bytes memory data;

        if (useSai) {
            data = abi.encodeWithSignature('wipe(bytes32, uint)', cup, wad);
        } else {
            //peth workflow
            //data = abi.encodeWithSignature('wipe(bytes32, uint)', cdp, wad);
        }

        require(
            manager.execTransactionFromModule(tub, value, data, operation), //call operation
            "CDPModule::topUp: INVALID_EXEC: TOP_UP"
        );

        require(
            Tub(tub).safe(cup),
            "CDPModule::topUp: INVALID_STATE: CDP_AT_RISK_TOP_FAILED"
        );
    }


    function _checkHash(
        bytes32 hash,
        bytes memory signatures
    )
    internal
    view
    returns (
        bool valid
    )
    {
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint256 i;
        uint256 threshold = OwnerManager(address(manager)).getThreshold();
        // Validate threshold is reached.
        valid = false;

        for (i = 0; i < threshold; i++) {

            currentOwner = recoverKey(
                hash,
                signatures, i
            );

            require(
                OwnerManager(address(manager)).isOwner(currentOwner),
                "CDPModule::_checkHash: INVALID_DATA: SIGNATURE_NOT_OWNER"
            );

            require(
                currentOwner > lastOwner,
                "CDPModule::_checkHash: INVALID_DATA: SIGNATURE_OUT_ORDER"
            );

            lastOwner = currentOwner;
        }

        valid = true;
    }

}
