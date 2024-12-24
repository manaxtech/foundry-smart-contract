// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256) {
        console.log("Creating subscription on chainId ", block.chainid);
        console.log("Using vrfCoordinator ", vrfCoordinator);

        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Your subscriptionId is ", subId);
        console.log("Update the SubscriptionId in the HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint256) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 constant FUND_AMOUNT = 30 ether; // cheaper sepolia LINK
    uint256 constant ANVIL_FUND_AMOUNT = 300 ether; // expensive anvil link

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptId, link);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subId,
        address linkToken
    ) public {
        console.log("Funding subscription", subId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast();
            vm.stopBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                ANVIL_FUND_AMOUNT
            );
        } else {
            vm.startBroadcast();
            LinkTokenInterface(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address contractAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        addConsumer(vrfCoordinator, subscriptionId, contractAddress);
    }

    function addConsumer(
        address vrfCoordinator,
        uint256 subId,
        address contractAddress
    ) public {
        console.log("Adding consumer ", contractAddress);
        console.log("To subscriptionId ", subId);
        console.log("Using vrfCoordinator ", vrfCoordinator);
        console.log("On chainId ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractAddress
        );
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentDeployment);
    }
}
