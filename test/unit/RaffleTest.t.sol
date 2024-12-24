// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle raffle;
    DeployRaffle deployer;
    HelperConfig helperConfig;

    address PLAYER = makeAddr("player");
    uint256 constant SEND_VALUE = 0.01 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event RaffleWinnerRequested(uint256 indexed requestId);

    function setUp() public {
        deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    /////////////////////////////////////////////////////////////////////////
    // INITIALIZATION
    /////////////////////////////////////////////////////////////////////////
    function test_EntranceFeeIntervalIsAccurate() public view {
        uint256 expectedEntranceFee = ENTRANCE_FEE;
        uint256 expectedInterval = INTERVAL;

        uint256 recordedEntranceFee = raffle.getEntranceFee();
        uint256 recordedInterval = raffle.getInterval();

        assert(recordedEntranceFee == expectedEntranceFee);
        assert(recordedInterval == expectedInterval);
    }

    function test_LastTimeStampInitializes() public view {
        uint256 expectedTimestamp = block.timestamp;
        uint256 actualTimestamp = raffle.getLastTimeStamp();

        assert(actualTimestamp <= expectedTimestamp);
    }

    function test_RaffleStateInitializesInOpenState() public view {
        Raffle.RaffleState expectedRaffleState = Raffle.RaffleState.OPEN;
        Raffle.RaffleState recordedRaffleState = raffle.getRaffleState();

        assert(recordedRaffleState == expectedRaffleState);
    }

    /////////////////////////////////////////////////////////////////////////
    // ENTER RAFFLE
    /////////////////////////////////////////////////////////////////////////

    function test_CantEnterRaffleWithoutEnoughEth() public {
        vm.expectRevert(Raffle.Raffle__MustSendEnoughEthToEnterRaffle.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle();
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
        _;
    }

    function test_EnterRaffleUpdatesDataStructure() public raffleEntered {
        address recordedPlayer = raffle.getPlayer(0);
        assert(recordedPlayer == PLAYER);
    }

    function test_EnterRaffleEmitsEvent() public {
        vm.expectEmit();
        emit RaffleEntered(PLAYER);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: SEND_VALUE}();
    }

    /////////////////////////////////////////////////////////////////////////
    // CHECKUPKEEP
    /////////////////////////////////////////////////////////////////////////
    function test_CheckUpkeepReturnsFalseIfNotTimePassed()
        public
        raffleEntered
    {
        uint256 amountTimePassed = block.timestamp - raffle.getLastTimeStamp();
        uint256 numPlayers = raffle.getNumPlayers();
        uint256 balance = address(raffle).balance;
        uint256 rState = uint256(raffle.getRaffleState());
        console.log("Amount of time passed is", amountTimePassed);
        console.log(
            "Number of Players is ",
            numPlayers,
            "and Balance is: ",
            balance
        );
        console.log("Raffle State is: ", rState);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    modifier timePassed() {
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.roll(block.number + 1);
        _;
    }

    function test_CheckUpkeepReturnsFalseIfNoPlayersNoBalance()
        public
        timePassed
    {
        uint256 amountTimePassed = block.timestamp - raffle.getLastTimeStamp();
        uint256 numPlayers = raffle.getNumPlayers();
        uint256 balance = address(raffle).balance;
        uint256 rState = uint256(raffle.getRaffleState());
        console.log("Amount of time passed is", amountTimePassed);
        console.log(
            "Number of Players is ",
            numPlayers,
            "and Balance is: ",
            balance
        );
        console.log("Raffle State is: ", rState);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function test_CheckUpkeepReturnFalseIfRaffleNotOpened()
        public
        raffleEntered
        timePassed
    {
        raffle.performUpkeep("");

        uint256 amountTimePassed = block.timestamp - raffle.getLastTimeStamp();
        uint256 numPlayers = raffle.getNumPlayers();
        uint256 balance = address(raffle).balance;
        uint256 rState = uint256(raffle.getRaffleState());
        console.log("Amount of time passed is", amountTimePassed);
        console.log(
            "Number of Players is ",
            numPlayers,
            "and Balance is: ",
            balance
        );
        console.log("Raffle State is: ", rState);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function test_CheckUpkeepReturnsTrueIfAllParametersAreGood()
        public
        raffleEntered
        timePassed
    {
        uint256 amountTimePassed = block.timestamp - raffle.getLastTimeStamp();
        uint256 numPlayers = raffle.getNumPlayers();
        uint256 balance = address(raffle).balance;
        uint256 rState = uint256(raffle.getRaffleState());
        console.log("Amount of time passed is", amountTimePassed);
        console.log(
            "Number of Players is ",
            numPlayers,
            "and Balance is: ",
            balance
        );
        console.log("Raffle State is: ", rState);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /////////////////////////////////////////////////////////////////////////
    // PERFORMUPKEEP
    /////////////////////////////////////////////////////////////////////////

    function test_PerformUpkeepRevertsIfCheckupkeepIsFalse() public {
        uint256 numPlayers = 0;
        uint256 balance = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                numPlayers,
                balance,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpkeepRevertsIfCheckupkeepIsFalseByClalculatingRaffle()
        public
        raffleEntered
        timePassed
    {
        raffle.performUpkeep("");

        uint256 numPlayers = 1;
        uint256 balance = SEND_VALUE;
        uint256 raffleState = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                numPlayers,
                balance,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function test_PerfomUpkeepMakesRaffleStateCalculating()
        public
        raffleEntered
        timePassed
    {
        Raffle.RaffleState previousRaffleState = raffle.getRaffleState();

        raffle.performUpkeep("");

        Raffle.RaffleState recentRaffleState = raffle.getRaffleState();

        assert(previousRaffleState == Raffle.RaffleState.OPEN);
        assert(recentRaffleState == Raffle.RaffleState.CALCULATING);
    }

    function test_PerformUpkeepEmitsEvents() public raffleEntered timePassed {
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];

        assertEq(uint256(requestId), 1);
    }

    /////////////////////////////////////////////////////////////////////////
    // FULFILLRANDOMWORDS
    /////////////////////////////////////////////////////////////////////////

    function test_fulfillRandomWordsPicksWinnerUPdatesDataStructureAndSendMoney()
        public
        raffleEntered
        timePassed
    {
        // Arrange
        uint160 numPlayers = 10;
        uint160 startngIndex = 1;

        for (uint160 i = startngIndex; i < numPlayers; i++) {
            hoax(address(i), SEND_VALUE);
            raffle.enterRaffle{value: SEND_VALUE}();
        }

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];

        VRFCoordinatorV2_5Mock(helperConfig.getConfig().vrfCoordinator)
            .fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        assert(raffle.getRecentWinner() == address(1));
    }
}

// [ the entire Log array
//     ( one log
//         [0x4549df58a7d250647f89fe30531ce89d7a67e57126a474379b9e64af26785203, 0x0000000000000000000000000000000000000000000000000000000000000000], array of topic
//         0x, data
//         0x90193C961A926261B756D1E5bb255e67ff9498A1 emitter
//     )
// ]
