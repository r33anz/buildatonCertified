// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/TestHelpers.sol";
import {DocumentTypes} from "../../src/libraries/DocumentTypes.sol";    

contract DocumentSystemIntegrationTest is TestHelpers {
    using DocumentTypes for *;
    
    // Test complete document workflow from creation to completion
    function test_CompleteDocumentWorkflow() public {
        // 1. Create document
        vm.startPrank(admin);
        
        bytes32[] memory requiredRoles = new bytes32[](3);
        requiredRoles[0] = actualRegistrarRole;
        requiredRoles[1] = actualDeanRole;
        requiredRoles[2] = actualDirectorRole;
        
        uint256 tokenId = documentNFT.createDocument(
            student,
            "Test Certificate",
            "A test graduation certificate",
            "QmTestHash123",
            keccak256("test document content"),
            block.timestamp + 30 days,
            requiredRoles,
            "GRADUATION_CERTIFICATE"
        );

        // 2. Create workflow template - ESTA ES LA LÍNEA QUE FALLA
        
        // Verificar que admin tiene el rol correcto antes de crear la plantilla
        require(
            documentWorkflow.hasRole(documentWorkflow.WORKFLOW_ADMIN_ROLE(), admin),
            "Admin should have WORKFLOW_ADMIN_ROLE"
        );
        
        // Crear plantilla si no existe
        if (documentWorkflow.getWorkflowTemplate("GRADUATION_CERTIFICATE").length == 0) {
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
            
            documentWorkflow.createWorkflowTemplate(
                "GRADUATION_CERTIFICATE",
                templateRoles,
                isRequired,
                order,
                deadlines
            );
        }
        
        // 3. Create workflow for the document
        
        documentWorkflow.createDocumentWorkflow(tokenId, "GRADUATION_CERTIFICATE");

        vm.stopPrank();

        // Verify initial state
        DocumentTypes.Document memory doc = documentNFT.getDocument(tokenId);
        assertEq(uint(doc.state), uint(DocumentTypes.DocumentState.PENDING_SIGNATURES));
        assertEq(doc.title, "Test Certificate");
        assertEq(documentNFT.getBeneficiary(tokenId), student);

        bytes32 documentHash = keccak256("test document content");

        // 4. Sign through workflow in correct order
        _signThroughWorkflow(registrar, tokenId, 0, documentHash); // Step 0: Registrar
        _signThroughWorkflow(dean, tokenId, 1, documentHash);      // Step 1: Dean  
        _signThroughWorkflow(director, tokenId, 2, documentHash);  // Step 2: Director

        // Verify completion - workflow should automatically update document state
        doc = documentNFT.getDocument(tokenId);
        assertEq(uint(doc.state), uint(DocumentTypes.DocumentState.COMPLETED));

        // Verify all signatures
        DocumentTypes.DocumentSignature[] memory signatures = signatureManager.getDocumentSignatures(tokenId);
        assertEq(signatures.length, 3);
        assertEq(signatures[0].signer, registrar);
        assertEq(signatures[1].signer, dean);
        assertEq(signatures[2].signer, director);

        // Verify workflow is completed
        DocumentTypes.DocumentWorkflowData memory workflow = documentWorkflow.getDocumentWorkflow(tokenId);
        assertTrue(workflow.isCompleted);
        assertEq(workflow.currentStep, workflow.steps.length);
    }
    
    // Test workflow step validation and order enforcement
    function test_WorkflowStepValidation() public {
        // Create a test document and get its tokenId and documentHash
        uint256 tokenId = _createTestDocument();
        bytes32 documentHash = keccak256("test document content");
        
        DocumentTypes.DocumentWorkflowData memory workflow = documentWorkflow.getDocumentWorkflow(tokenId);
        assertEq(workflow.currentStep, 0, "Workflow should start at step 0");
        assertGt(workflow.steps.length, 0, "Workflow should have steps");
        
        // Get the deadline and create proper signature for step 1 (dean)
        uint256 step1Deadline = workflow.steps[1].deadline;
        bytes32 step1Role = workflow.steps[1].role;
        
        // Create proper signature for dean
        bytes32 structHash = keccak256(abi.encode(
            keccak256("DocumentSignature(uint256 documentId,address signer,bytes32 role,bytes32 documentHash,uint256 deadline)"),
            tokenId,
            dean,
            step1Role,
            documentHash,
            step1Deadline
        ));
        
        bytes32 domainSeparator = signatureManager.domainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deanPk, digest);
        bytes memory deanSignature = abi.encodePacked(r, s, v);
        
        // Try to sign out of order (should fail) - attempt step 1 before completing step 0
        vm.expectRevert("Must complete steps in order");
        vm.prank(dean);
        documentWorkflow.completeWorkflowStep(tokenId, 1, documentHash, deanSignature);
        
        // Sign step 0 first (this should succeed)
        _signThroughWorkflow(registrar, tokenId, 0, documentHash);
        
        // Now dean can sign step 1
        vm.prank(dean);
        documentWorkflow.completeWorkflowStep(tokenId, 1, documentHash, deanSignature);
        
        // Verify workflow progress
        workflow = documentWorkflow.getDocumentWorkflow(tokenId);
        assertEq(workflow.currentStep, 2, "Should be at director step");
        assertFalse(workflow.isCompleted, "Not completed yet");
    }
    
    // Test multiple institutions deployment
    function test_MultipleInstitutions() public {
        // Deploy second institution
        vm.prank(admin);
        DocumentFactory.DeployedContracts memory contracts2 = factory.deployInstitutionSystem(
            "Second_University",
            "Second University Docs",
            "SUD",
            admin
        );
        
        // Verify both institutions exist
        string[] memory institutions = factory.getAllInstitutions();
        assertEq(institutions.length, 2);
        assertEq(institutions[0], INSTITUTION_NAME);
        assertEq(institutions[1], "Second_University");
        
        // Verify contracts are different
        assertTrue(contracts2.institutionDAO != address(institutionDAO));
        assertTrue(contracts2.documentNFT != address(documentNFT));
        assertTrue(contracts2.signatureManager != address(signatureManager));
        assertTrue(contracts2.documentWorkflow != address(documentWorkflow));
        
        // Verify second institution is active
        DocumentFactory.DeployedContracts memory retrieved = factory.getInstitutionContracts("Second_University");
        assertTrue(retrieved.isActive);
        assertEq(retrieved.institutionDAO, contracts2.institutionDAO);
    }
    
    // Test role management functionality
    function test_RoleManagement() public {
        // Test role granting
        vm.prank(admin);
        institutionDAO.grantMemberRole(student, actualViewerRole);
        
        bytes32[] memory studentRoles = institutionDAO.getMemberRoles(student);
        assertGt(studentRoles.length, 0);
        
        // Test role revoking
        vm.prank(admin);
        institutionDAO.revokeMemberRole(registrar, actualSignatoryRole);
        
        bytes32[] memory registrarRoles = institutionDAO.getMemberRoles(registrar);
        // Should still have actualRegistrarRole but not actualSignatoryRole
        bool hasSignatoryRole = false;
        for (uint i = 0; i < registrarRoles.length; i++) {
            if (registrarRoles[i] == actualSignatoryRole) {
                hasSignatoryRole = true;
                break;
            }
        }
        assertFalse(hasSignatoryRole);
        
        // Verify still has registrar role
        assertTrue(institutionDAO.hasRole(actualRegistrarRole, registrar));
    }
    
    // Test factory admin controls
    function test_FactoryAdminControls() public {
        // Test institution deactivation
        vm.prank(admin);
        factory.deactivateInstitution(INSTITUTION_NAME);
        
        DocumentFactory.DeployedContracts memory contracts = factory.getInstitutionContracts(INSTITUTION_NAME);
        assertFalse(contracts.isActive);
        
        // Test institution reactivation
        vm.prank(admin);
        factory.reactivateInstitution(INSTITUTION_NAME);
        
        contracts = factory.getInstitutionContracts(INSTITUTION_NAME);
        assertTrue(contracts.isActive);
        
        // Test non-admin cannot control institutions
        vm.prank(student);
        vm.expectRevert();
        factory.deactivateInstitution(INSTITUTION_NAME);
    }
    
    // Test document creation with different beneficiaries
    function test_DocumentCreationWithDifferentBeneficiaries() public {
        // Create document for registrar (who is also a member)
        vm.prank(admin);
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = actualDeanRole;
        
        uint256 tokenId = documentNFT.createDocument(
            registrar,
            "Staff Certificate",
            "Internal staff certification",
            "QmTestHash456",
            keccak256("staff certificate content"),
            block.timestamp + 15 days,
            requiredRoles,
            "STAFF_CERTIFICATE"
        );
        
        assertEq(documentNFT.getBeneficiary(tokenId), registrar);
        
        // Verify beneficiary has the NFT
        assertEq(documentNFT.ownerOf(tokenId), registrar);
    }
    
    // Test workflow template creation and management
    function test_WorkflowTemplateManagement() public {
        // Create a new workflow template
        vm.prank(admin);
        bytes32[] memory templateRoles = new bytes32[](2);
        templateRoles[0] = actualDeanRole;
        templateRoles[1] = actualDirectorRole;
        
        bool[] memory isRequired = new bool[](2);
        isRequired[0] = true;
        isRequired[1] = true;
        
        uint256[] memory order = new uint256[](2);
        order[0] = 0;
        order[1] = 1;
        
        uint256[] memory deadlines = new uint256[](2);
        deadlines[0] = block.timestamp + 5 days;
        deadlines[1] = block.timestamp + 10 days;
        
        documentWorkflow.createWorkflowTemplate(
            "DIPLOMA_CERTIFICATE",
            templateRoles,
            isRequired,
            order,
            deadlines
        );
        
        // Verify template was created
        DocumentTypes.WorkflowStep[] memory template = documentWorkflow.getWorkflowTemplate("DIPLOMA_CERTIFICATE");
        assertEq(template.length, 2);
        assertEq(template[0].role, actualDeanRole);
        assertEq(template[1].role, actualDirectorRole);
    }
    
    // Test signature verification
    function test_SignatureVerification() public {
        uint256 tokenId = _createTestDocument();
        bytes32 documentHash = keccak256("test document content");
        
        // Sign first step
        _signThroughWorkflow(registrar, tokenId, 0, documentHash);
        
        // Verify signature count
        assertEq(signatureManager.getSignatureCount(tokenId), 1);
        
        // Get signatures and verify details
        DocumentTypes.DocumentSignature[] memory signatures = signatureManager.getDocumentSignatures(tokenId);
        assertEq(signatures.length, 1);
        assertEq(signatures[0].signer, registrar);
        assertEq(signatures[0].role, actualRegistrarRole);
        assertTrue(signatures[0].isValid);
    }
    
    // Fuzz test for document creation with various parameters
    function testFuzz_DocumentCreation(
        string memory title,
        string memory description,
        uint256 deadline
    ) public {
        // Bound deadline to reasonable range
        deadline = bound(deadline, block.timestamp + 1 days, block.timestamp + 365 days);
        
        // Skip if title is empty
        if (bytes(title).length == 0) return;
        
        vm.prank(admin);
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = actualRegistrarRole;
        
        uint256 tokenId = documentNFT.createDocument(
            student,
            title,
            description,
            "QmTestHash",
            keccak256(bytes(title)),
            deadline,
            requiredRoles,
            "TEST_DOCUMENT"
        );
        
        DocumentTypes.Document memory doc = documentNFT.getDocument(tokenId);
        assertEq(doc.title, title);
        assertEq(doc.description, description);
        assertEq(doc.deadline, deadline);
        assertEq(documentNFT.getBeneficiary(tokenId), student);
    }
    
    // Test NFT transfer restrictions
    function test_NFTTransferRestrictions() public {
        uint256 tokenId = _createTestDocument();
        
        // NFTs should be non-transferable (soul-bound)
        vm.prank(student);
        vm.expectRevert("Document NFTs are non-transferable");
        documentNFT.transferFrom(student, admin, tokenId);
    }
}