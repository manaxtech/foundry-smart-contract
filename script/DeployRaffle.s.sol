// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }

    function deployRaffle()
        private
        returns (Raffle raffle, HelperConfig helperConfig)
    {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription cSub = new CreateSubscription();
            config.subscriptionId = cSub.createSubscription(
                config.vrfCoordinator
            );

            FundSubscription fSub = new FundSubscription();
            fSub.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link
            );
        }

        vm.startBroadcast();
        raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            config.vrfCoordinator,
            config.subscriptionId,
            address(raffle)
        );

        return (raffle, helperConfig);
    }
}
