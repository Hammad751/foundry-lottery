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
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();

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

    // 1. Get a random number
    // 2. Use the random number to pick the winner
    // 3. Be automatically called
    function pickWinner() public {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
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
    }

    function fulfillRandomWords(
        uint256 requestId,
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
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit PickedWinner(winner);
    }

    /** Getter */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
