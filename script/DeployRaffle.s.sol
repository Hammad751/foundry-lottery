// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubScription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    constructor() {}

    function run() external returns(Raffle, HelperConfig){
        // deploy helperConfig file
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();

        // get the configuration
        (uint256 entFee,
        uint256 interval,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator,
        bytes32 keyHash, 
        address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubScription subscription = new CreateSubScription();
            (subscriptionId, vrfCoordinator) = subscription.createSubscription(vrfCoordinator, deployerKey);

            // Funde it after creation of subscription
            FundSubscription fundsubscription = new FundSubscription();
            fundsubscription.fundSubscription(subscriptionId, vrfCoordinator, link, deployerKey);
        }

        // now deploy the Raffle contract
        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle( 
            entFee,
            interval,
            subscriptionId,
            callbackGasLimit,
            vrfCoordinator,
            keyHash
        );

        vm.stopBroadcast();
        
        // AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(subscriptionId, vrfCoordinator, address(raffle), deployerKey);
        return (raffle, helperConfig);
    }
}