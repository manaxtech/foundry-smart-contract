// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /********************** Errors **********************/
    error Raffle__MustSendEnoughEthToEnterRaffle();
    error Raffle__UpkeepNotNeeded(
        uint256 numPlayers,
        uint256 balance,
        uint256 raffleState
    );
    error Raffle__TransferFailed();

    /********************** DataTypes **********************/
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /********************** Variables **********************/
    // Chainlink VRF variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    // raffle variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /********************** Events **********************/
    event RaffleEntered(address indexed player);
    event RaffleWinnerRequested(uint256 indexed requestId);
    event RaffleWinnerPicked(address indexed winner);

    /********************** Modifiers **********************/
    /********************** Functions **********************/
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__MustSendEnoughEthToEnterRaffle();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        upkeepNeeded = (hasTimePassed && hasPlayers && hasBalance && isOpen);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes memory /*performData*/) public {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                s_players.length,
                address(this).balance,
                uint256(s_raffleState)
            );
        }

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(req);

        s_raffleState = RaffleState.CALCULATING;

        emit RaffleWinnerRequested(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = (randomWords[0] % s_players.length);
        address payable winner = s_players[winnerIndex];

        s_recentWinner = winner;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);

        emit RaffleWinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /********************** Getters **********************/

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getNumPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
}
