// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/DocumentFactory.sol";
import "../src/InstitutionDAO.sol";
import "../src/DocumentSignatureManager.sol";
import "../src/DocumentNFT.sol";
import "../src/DocumentWorkflow.sol";

contract DeployFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOY COMPLETE SYSTEM ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy templates
        InstitutionDAO institutionDAOTemplate = new InstitutionDAO();
        DocumentSignatureManager signatureManagerTemplate = new DocumentSignatureManager();
        DocumentNFT documentNFTTemplate = new DocumentNFT();
        DocumentWorkflow documentWorkflowTemplate = new DocumentWorkflow();

        // 2. Deploy factory
        DocumentFactory documentFactory = new DocumentFactory();
        documentFactory.initialize();

        // 3. Set templates in factory
        documentFactory.setTemplates(
            address(institutionDAOTemplate),
            address(signatureManagerTemplate),
            address(documentNFTTemplate),
            address(documentWorkflowTemplate)
        );

        vm.stopBroadcast();

        // 4. Save all to JSON
        string memory contractsJson = string(
            abi.encodePacked(
                '{\n',
                '  "network": "anvil",\n',
                '  "chainId": ', vm.toString(block.chainid), ',\n',
                '  "deployedAt": ', vm.toString(block.timestamp), ',\n',
                '  "deployer": "', vm.toString(deployer), '",\n',
                '  "admin": null,\n',
                '  "factory": "', vm.toString(address(documentFactory)), '",\n',
                '  "templates": {\n',
                '    "institutionDAO": "', vm.toString(address(institutionDAOTemplate)), '",\n',
                '    "signatureManager": "', vm.toString(address(signatureManagerTemplate)), '",\n',
                '    "documentNFT": "', vm.toString(address(documentNFTTemplate)), '",\n',
                '    "documentWorkflow": "', vm.toString(address(documentWorkflowTemplate)), '"\n',
                '  },\n',
                '  "institution": null\n',
                '}'
            )
        );

        vm.writeFile("./deployed-contracts.json", contractsJson);

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("DocumentFactory:", address(documentFactory));
        console.log("InstitutionDAO Template:", address(institutionDAOTemplate));
        console.log("SignatureManager Template:", address(signatureManagerTemplate));
        console.log("DocumentNFT Template:", address(documentNFTTemplate));
        console.log("DocumentWorkflow Template:", address(documentWorkflowTemplate));
        console.log("Contract data saved to deployed-contracts.json");
    }
}
