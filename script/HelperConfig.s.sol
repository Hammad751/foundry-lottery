// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script{
    // we add this structure having the values given in the Raffle contract
    struct NetworkConfig{
        uint256 entFee;
        uint256 interval;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        bytes32 keyHash;
        address link;
        uint256 deployerKey;
    }

    // write some constructor configuration 
    NetworkConfig public activeNetworkConfig;
    
    event Helper_MockConfigCreated(address vrfCoordinator);

    constructor(){
        if(block.chainid == 80001){
            activeNetworkConfig = getMumbaiChainConfig();
        }
        else{
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    // Now get the network configuration
    function getMumbaiChainConfig() public view returns(NetworkConfig memory mumbaiConfig){
        mumbaiConfig = NetworkConfig({
            entFee: 0.001 ether,
            interval: 30,
            subscriptionId: 7260,
            callbackGasLimit: 500000,
            vrfCoordinator: 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            keyHash: 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            link: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    // for main chain configuration
    // function getMainChainConfig() public pure returns(NetworkConfig memory){
    //     return NetworkConfig({
    //         entFee: 0.001 ether,
    //         interval: 30,
    //         subscriptionId: 0, // update through subId
    //         callbackGasLimit: 500000,
    //         vrfCoordinator: 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
    //         keyHash: 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
    //     });
    // }

    // for completely local-chain/anvil-chain we use mock coordinators from chianlink
    function getOrCreateAnvilConfig() public returns(NetworkConfig memory anvilConfiguration){
        // check if there is non-empty coordinator address
        if(activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }
        // to deploy on any chain use vm-broadcast
        // add baseFee and gasPriceLink
        uint96 baseFee = 0.025 ether; // LINK
        uint96 gasPriceLink = 1e9;  // 1 gwei LINK

        vm.startBroadcast(vm.envUint("ANVIL_PRIVATE_KEY"));
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        // for mock configuration we also have to deploy the link token manually

        emit Helper_MockConfigCreated(address(vrfCoordinatorMock));

        anvilConfiguration = NetworkConfig({
            entFee: 0.001 ether,
            interval: 30,
            subscriptionId: 0, // update through subId
            callbackGasLimit: 500000,
            vrfCoordinator: address(vrfCoordinatorMock),
            keyHash: 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            link: address(link),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });
    }
}