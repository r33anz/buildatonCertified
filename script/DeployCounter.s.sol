// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Counter.sol";

contract DeployCounter is Script {
    function run() external {
        // Opcionalmente: cargar clave privada desde entorno
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        new Counter();
        vm.stopBroadcast();
    }
}
