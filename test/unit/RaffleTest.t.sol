// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

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
    address link;
    uint256 deployerKey;

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
         keyHash, link,deployerKey) = helperConfig.activeNetworkConfig();
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
    
    modifier raffleEnteredTimePassed(){
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    // to check the conditions having time calculations, we can use mock values using "vm"
    function testWhenRaffleStateCalculating() 
    public
    raffleEnteredTimePassed
    {
        raffel.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entFee}();
    }

    /////////////////////
    // checkUpkeep    //
    ////////////////////

    function testCheckUpKeepReturnsFalseIfNoBalance() public{
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded, ) = raffel.checkUpKeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpKeepRaffleNoteOPEN() 
    public
    raffleEnteredTimePassed 
    {
        raffel.performUpkeep("");
        (bool upKeepNeeded, ) = raffel.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testcheckUpKeepNotEnoughTimePassed() public{
        vm.prank(PLAYER); // this will set the caller address
        raffel.enterRaffle{value: entFee}();
        skip(interval-1);

        (bool upKeepNeeded, ) = raffel.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    /////////////////////
    // performUpKeep  //
    ////////////////////
    

    function testPerformUpKeepRunsOnlyIfCheckUpKeepIsTrue() 
    public
    raffleEnteredTimePassed
    {   raffel.performUpkeep("");  }

    function testPerformUpKeepShouldRevert_1() public {
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entFee}();
        skip(interval - 1);
        vm.expectRevert();
        raffel.performUpkeep("");
    }

    function testPerformUpKeepShouldRevert_2() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__upKeepNotNeeded.selector, 
                0, 
                0, 
                0
            )
        );
        raffel.performUpkeep("");
    }

    function testPerformUpKeepRaffleStateAndEmitRequestId() 
    public 
    raffleEnteredTimePassed
    {
        vm.recordLogs();
        raffel.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffel.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    function fulfillRandomWordsCanonlyBeCalledAfterPerformUpKeep(
        uint256 randomeRequestId
    ) 
    public 
    raffleEnteredTimePassed
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).
        fulfillRandomWords(randomeRequestId, address(raffel));

    }

    function fulfillRandomWordsPickWinnerResetAndSendMoney() 
    public 
    raffleEnteredTimePassed // here we have 1 entrant
    {
        uint256 additionalEntrant = 5; // here we add 5 more entrants in the testing phase
        uint256 startingIndex = 1;

        for(; startingIndex <= additionalEntrant; startingIndex++){
            address player = address(uint160(startingIndex));
            hoax(player, initalBalance);
            raffel.enterRaffle{value: entFee}();
        }
        // pretend to be chainlink vrf and pick the winner

        // get the logs
        vm.recordLogs();
        raffel.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 prevTimeStamp = raffel.getLastTimeStamp();
        VRFCoordinatorV2Mock(vrfCoordinator).
        fulfillRandomWords(uint256(requestId), address(raffel));

        uint256 prize = entFee * (additionalEntrant + 1);


        console.log(prize);
        console.log(raffel.getRecentWinner().balance);

        assert(uint256(raffel.getRaffleState()) != 0);
        assert(raffel.getRecentWinner() != address(0));
        assert(raffel.getPlayersLength() == 0);
        assert(prevTimeStamp < raffel.getLastTimeStamp());
        assert(raffel.getRecentWinner().balance == initalBalance + prize - entFee);
    }
}