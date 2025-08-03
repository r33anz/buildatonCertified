// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/DocumentFactory.sol";

contract DeployInstitution is Script {
    function run() external {
        // Usar la cuenta deployer que tiene permisos en el factory
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        // La cuenta 1 será el admin de la institución
        address institutionAdmin = vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
        
        // Factory address from your deployment
        address factoryAddress = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
        
        console.log("=== DEPLOYING INSTITUTION TO ANVIL ===");
        console.log("Deployer address:", deployer);
        console.log("Institution Admin:", institutionAdmin);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        console.log("Using Factory at:", factoryAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        DocumentFactory factory = DocumentFactory(factoryAddress);
        
        // Configuración de la institución
        string memory institutionName = "Universidad Nacional Anvil";
        string memory nftName = "UNA Document NFTs";
        string memory nftSymbol = "UNADOC";
        
        console.log("Deploying institution system...");
        console.log("Institution:", institutionName);
        console.log("NFT Name:", nftName);
        console.log("NFT Symbol:", nftSymbol);
        
        // Deploy del sistema institucional
        DocumentFactory.DeployedContracts memory contracts = factory.deployInstitutionSystem(
            institutionName,
            nftName,
            nftSymbol,
            institutionAdmin
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== INSTITUTION DEPLOYED ===");
        console.log("InstitutionDAO:", contracts.institutionDAO);
        console.log("SignatureManager:", contracts.signatureManager);
        console.log("DocumentNFT:", contracts.documentNFT);
        console.log("DocumentWorkflow:", contracts.documentWorkflow);
        
        // Crear archivo de contratos deployados
        string memory contractsJson = string(
            abi.encodePacked(
                '{\n',
                '  "network": "anvil",\n',
                '  "chainId": ', vm.toString(block.chainid), ',\n',
                '  "deployedAt": ', vm.toString(block.timestamp), ',\n',
                '  "deployer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",\n',
                '  "admin": "', vm.toString(institutionAdmin), '",\n',
                '  "factory": "', vm.toString(factoryAddress), '",\n',
                '  "templates": {\n',
                '    "institutionDAO": "0x5FbDB2315678afecb367f032d93F642f64180aa3",\n',
                '    "signatureManager": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",\n',
                '    "documentNFT": "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",\n',
                '    "documentWorkflow": "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"\n',
                '  },\n',
                '  "institution": {\n',
                '    "name": "', institutionName, '",\n',
                '    "institutionDAO": "', vm.toString(contracts.institutionDAO), '",\n',
                '    "signatureManager": "', vm.toString(contracts.signatureManager), '",\n',
                '    "documentNFT": "', vm.toString(contracts.documentNFT), '",\n',
                '    "documentWorkflow": "', vm.toString(contracts.documentWorkflow), '"\n',
                '  }\n',
                '}'
            )
        );
        
        vm.writeFile("./deployed-contracts.json", contractsJson);
        
        console.log("\n=== USEFUL ADDRESSES FOR TESTING ===");
        console.log("Deployer (Account 0):", 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        console.log("Admin (Account 1):", institutionAdmin);
        console.log("Account 2:", vm.addr(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a));
        console.log("Account 3:", vm.addr(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6));
        
        console.log("\n=== CONTRACT ADDRESSES SAVED ===");
        console.log("All addresses saved to deployed-contracts.json");
        console.log("Ready for testing!");
        console.log("=====================================");
    }
}