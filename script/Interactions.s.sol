// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubScription is Script {

    function createSubscriptionUsingConfig() public returns(uint64, address){
        HelperConfig helperConfig = new HelperConfig();
        // get the configuration
        (,,,,address vrfCoordinator,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns(uint64, address){
        console.log("Creating subscription Id on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your chainid: ", subId);
        console.log("Update subId in config file");
        return (subId, vrfCoordinator);
    }


    function run() external returns(uint64, address){
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
        (,,uint64 subId,,address vrfCoordinator,, address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        fundSubscription(subId, vrfCoordinator, link, deployerKey);
    }

    function fundSubscription(uint64 subId, address vrfCoordinator, address link, uint256 deployerKey) public{
        if(block.chainid == 31337){
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, Fund_Amount);
            vm.stopBroadcast();
        }
        else {
            console.log("Link Balance: ", LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log("Contract balance: ", LinkToken(link).balanceOf(address(this)));

            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, Fund_Amount, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external{
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address recentRaffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (,,uint64 subID,,address VRFcoordinator,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(subID, VRFcoordinator, recentRaffle, deployerKey);
    }

    function addConsumer(uint64 subId, address VRFcoordinator, address raffle, uint256 deployerKey) public{
        console.log("Adding consumer contract: ", raffle);
        console.log("Using vrfCoordinator: ", VRFcoordinator);
        console.log("Chain id: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(VRFcoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }
    
    function run() external{
        address recentRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(recentRaffle);
    }
}