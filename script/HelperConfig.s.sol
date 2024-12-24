// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 constant ENTRANCE_FEE = 0.01 ether;
    uint256 constant INTERVAL = 30;

    uint96 constant MOCK_BASE_FEE = 0.25 ether; // base fee
    uint96 constant MOCK_GAS_PRICE_LINK = 1e9; // 1e9 wei to 1e18 wei LINK
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 constant SEPOLIA_CHAINID = 11155111;
    uint256 constant MAINNET_CHAINID = 1;
    uint256 constant LOCAL_CHAINID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__ChainNotConfigured(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig private localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) private networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAINID] = getSepoliaEthConfig();
        networkConfigs[MAINNET_CHAINID] = getMainnetEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) private returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAINID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__ChainNotConfigured(chainId);
        }
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: ENTRANCE_FEE,
                interval: INTERVAL,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 31924349901444823064464170750297429174656200409594175643585395483925426066642,
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getMainnetEthConfig() private pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: ENTRANCE_FEE,
                interval: INTERVAL,
                vrfCoordinator: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
                gasLane: 0x3fd2fec10d06ee8f65e7f2e95f5c56511359ece3f33960ad8a866ae24a8ff10b,
                subscriptionId: 0,
                callbackGasLimit: 500000,
                link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
            });
    }

    function getOrCreateAnvilEthConfig()
        private
        returns (NetworkConfig memory)
    {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockVrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory networkConfig = NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: address(mockVrfCoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken)
        });

        localNetworkConfig = networkConfig;

        return networkConfig;
    }
}
