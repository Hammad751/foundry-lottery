// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubScription is Script {

    function createSubscriptionUsingConfig() public returns(uint64){
        HelperConfig helperConfig = new HelperConfig();
        // get the configuration
        (,,,,address vrfCoordinator,,,) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns(uint64){
        console.log("Creating subscription Id on chainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your chainid: ", subId);
        console.log("Update subId in config file");
        return subId;
    }


    function run() external returns(uint64){
        return createSubscriptionUsingConfig();
    }
}

// Add fund subscription contract

/**
 * @title FundSubscription
 * @author Hammad
 * @notice Fund subscription through code
 * @dev Create a fundSubscription contract where funds will be added manually through code. 
 */

contract FundSubscription is Script{

    uint96 public constant Fund_Amount = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (,,uint64 subId,,address vrfCoordinator,, address link, ) = helperConfig.activeNetworkConfig();
        fundSubscription(subId, vrfCoordinator, link);
    }

    function fundSubscription(uint64 subId, address vrfCoordinator, address link) public{
        if(block.chainid == 31337){
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, Fund_Amount);
            vm.stopBroadcast();
        }
        else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, Fund_Amount, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external{
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (,,uint64 subID,,address VRFcoordinator,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(subID, VRFcoordinator, raffle, deployerKey);
    }

    function addConsumer(uint64 subId, address VRFcoordinator, address raffle, uint256 deployerKey) public{

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(VRFcoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }
    function run() external{
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffle);
    }
}