// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubScription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    constructor() {}

    function run() external returns(Raffle, HelperConfig){
        // deploy helperConfig file
        HelperConfig helperConfig = new HelperConfig();
        // get the configuration
        (uint256 entFee,
        uint256 interval,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator,
        bytes32 keyHash) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubScription subscription = new CreateSubScription();
            subscriptionId = subscription.createSubscription(vrfCoordinator);
        }

        // now deploy the Raffle contract
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entFee,
            interval,
            subscriptionId,
            callbackGasLimit,
            vrfCoordinator,
            keyHash
        );

        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}