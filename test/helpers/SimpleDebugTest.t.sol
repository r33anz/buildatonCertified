// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/TestHelpers.sol";
import {DocumentTypes} from "../../src/libraries/DocumentTypes.sol";

contract SimpleDebugTest is TestHelpers {
    
    function test_DebugRoleIssue() public {
        console.log("=== Starting debug test ===");
        console.log("Admin address:", admin);
        console.log("Admin has WORKFLOW_ADMIN_ROLE:", documentWorkflow.hasRole(documentWorkflow.WORKFLOW_ADMIN_ROLE(), admin));
        
        // Step 1: Just try to create a workflow template
        vm.prank(admin);
        
        bytes32[] memory templateRoles = new bytes32[](3);
        templateRoles[0] = actualRegistrarRole;
        templateRoles[1] = actualDeanRole;
        templateRoles[2] = actualDirectorRole;
        
        bool[] memory isRequired = new bool[](3);
        isRequired[0] = true;
        isRequired[1] = true;
        isRequired[2] = true;
        
        uint256[] memory order = new uint256[](3);
        order[0] = 0;
        order[1] = 1;
        order[2] = 2;
        
        uint256[] memory deadlines = new uint256[](3);
        deadlines[0] = block.timestamp + 7 days;
        deadlines[1] = block.timestamp + 14 days;
        deadlines[2] = block.timestamp + 21 days;
        
        console.log("About to call createWorkflowTemplate with msg.sender:", msg.sender);
        console.log("templateRoles.length:", templateRoles.length);
        console.log("isRequired.length:", isRequired.length);
        
        // This is where it should fail - let's see exactly what happens
        documentWorkflow.createWorkflowTemplate(
            "GRADUATION_CERTIFICATE",
            templateRoles,
            isRequired,
            order,
            deadlines
        );
        
        console.log("Template created successfully!");
    }
    
    function test_CheckAllRoles() public {
        console.log("=== Checking all roles ===");
        console.log("Admin:", admin);
        console.log("Factory:", address(factory));
        console.log("DocumentWorkflow:", address(documentWorkflow));
        
        bytes32 workflowAdminRole = documentWorkflow.WORKFLOW_ADMIN_ROLE();
        bytes32 defaultAdminRole = documentWorkflow.DEFAULT_ADMIN_ROLE();
        bytes32 creatorRole = documentWorkflow.CREATOR_ROLE();
        
        console.log("WORKFLOW_ADMIN_ROLE hash:", vm.toString(workflowAdminRole));
        console.log("DEFAULT_ADMIN_ROLE hash:", vm.toString(defaultAdminRole));
        console.log("CREATOR_ROLE hash:", vm.toString(creatorRole));
        
        console.log("Admin has WORKFLOW_ADMIN_ROLE:", documentWorkflow.hasRole(workflowAdminRole, admin));
        console.log("Admin has DEFAULT_ADMIN_ROLE:", documentWorkflow.hasRole(defaultAdminRole, admin));
        console.log("Admin has CREATOR_ROLE:", documentWorkflow.hasRole(creatorRole, admin));
        
        console.log("Factory has WORKFLOW_ADMIN_ROLE:", documentWorkflow.hasRole(workflowAdminRole, address(factory)));
        console.log("Factory has DEFAULT_ADMIN_ROLE:", documentWorkflow.hasRole(defaultAdminRole, address(factory)));
    }
}