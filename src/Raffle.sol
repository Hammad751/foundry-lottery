// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
/**
 * @title A sample Raffle Contract
 * @author Hammad
 * @notice This contract is for creating sample Raffle contract
 * @dev Implements chainlink VRF V2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotOpen();
    error Raffle__TransferFailed();
    error Raffle__NotEnoughEthSent();
    error Raffle__upKeepNotNeeded(
        uint256 currentBalance, 
        uint256 numPlayers, 
        uint256 raffleState
    );

    /** Type declarations */
    enum RaffleState{
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    RaffleState private s_raffleState;
    bytes32 private immutable i_keyHash;

    uint256 private s_lastTimeStamp;

    address private s_recentWinner;
    address payable[] private s_players;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entFee,
        uint256 _interval,
        uint64 _subscriptionId, 
        uint32 _callbackGasLimit,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entFee;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        i_keyHash = _keyHash;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "not enough ETH sent");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__NotOpen();
        }
        
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that chainlink Automation nodes to be called
     * to see if it is the time to perform upkeep
     * The following should be true to return true
     * 1. The time interval has passed between raffle runs
     * 2. The Raffle is in the OPEN state
     * 3. The contract has ETH(aka, players)
     * 4. (Implicit) The subscription in needed with LINK
     */
    function checkUpKeep(bytes memory /** checkData */) 
    public view 
    returns(bool upKeepNeeded, bytes memory /** performedData */){
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "0x00");
    }

    // 1. Get a random number
    // 2. Use the random number to pick the winner
    // 3. Be automatically called
     function performUpkeep(
        bytes calldata /** performData */
    ) public {
        (bool upKeepNeeded, ) = checkUpKeep("");
        if(!upKeepNeeded){
            revert Raffle__upKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState) 
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // ID 7260
        // ETH/USD Mumbai MATIC
        // 0x0715A7794a1dc8e42615F059dD6e406A6594651A
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effecs, Interactions
    function fulfillRandomWords(
        uint256 /** requestId */,
        uint256[] memory randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        // reset the players array
        s_players = new address payable[](0);
        // and also reset the time
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

    }

    /** Getter */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }

    function getLastIndex() external view returns(uint256){
        return s_players.length - 1;
    }
    
    function getPlayer(uint256 playerIndex) external view returns(address){
        return s_players[playerIndex];
    }

    function getPlayersLength() external view returns(uint256){
        return s_players.length;
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}
