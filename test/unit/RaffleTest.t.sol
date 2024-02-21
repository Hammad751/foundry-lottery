// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract RaffleTest is Test {

    /** Events */
    event EnteredRaffle(address indexed player);

    Raffle raffel;
    HelperConfig helperConfig;

    // make these valraibles on state level 
    // so that these can be access at anywhere in the contract
    uint256 entFee;
    uint256 interval;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinator;
    bytes32 keyHash;

    // create a mock player address
    address public PLAYER = makeAddr("player");
    // give it initial balance
    uint256 public constant initalBalance = 10 ether;

    // create a setup for testing
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffel, helperConfig) = deployer.run();
        ( entFee,
         interval,
         subscriptionId,
         callbackGasLimit,
         vrfCoordinator,
         keyHash) = helperConfig.activeNetworkConfig();
         vm.deal(PLAYER, initalBalance);
    }

    function testRaffleInitializesOpenState() public view {
        assert(raffel.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////  EnetranceRaffle  ///////////////
    function testEntranceRaffleRevertWithNotEnoghPayment() public {
        // Arrange
        vm.prank(PLAYER); // this works on it takes player address as user
        // Act/assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffel.enterRaffle();
    }

    function testRaffelRecordsAfterEntrance() public {
        vm.prank(PLAYER);
        // to get the Record, first we have to enter so, we call entrance Function with accurate parameter
        raffel.enterRaffle{value: entFee}();
        uint256 playerIndex = raffel.getLastIndex();
        address recordedPlayer = raffel.getPlayer(playerIndex);

        assert(recordedPlayer == PLAYER);
    }

    function testEventEmittingOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffel)); // it takes four parameters by default

        emit EnteredRaffle(PLAYER);
        raffel.enterRaffle{value: entFee}();
    }

    // to check the conditions having time calculations, we can use mock values using "vm"
    function testWhenRaffleStateCalculating() public {
        vm.prank(PLAYER); // this will set the caller address
        raffel.enterRaffle{value: entFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffel.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entFee}();
    }
}