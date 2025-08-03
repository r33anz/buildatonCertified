// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {DocumentFactory} from "../../src/DocumentFactory.sol";
import {InstitutionDAO} from "../../src/InstitutionDAO.sol";
import {DocumentSignatureManager} from "../../src/DocumentSignatureManager.sol";
import {DocumentNFT} from "../../src/DocumentNFT.sol";
import {DocumentWorkflow} from "../../src/DocumentWorkflow.sol";

import "../../src/libraries/DocumentTypes.sol";

contract TestHelpers is Test {
    // Contracts
    DocumentFactory public factory;
    InstitutionDAO public institutionDAO;
    DocumentSignatureManager public signatureManager;
    DocumentNFT public documentNFT;
    DocumentWorkflow public documentWorkflow;
    
    // Test accounts with consistent private keys
    uint256 public adminPk = 0xa11ce;
    uint256 public registrarPk = 0xb0b;
    uint256 public deanPk = 0xc14a12;
    uint256 public directorPk = 0xd00d;
    uint256 public studentPk = 0xe1e;
    
    address public admin;
    address public registrar;
    address public dean;
    address public director;
    address public student;

    // Constants
    string constant INSTITUTION_NAME = "Test_University";
    string constant NFT_NAME = "Test University Documents";
    string constant NFT_SYMBOL = "TUD";
    
    // Store created role IDs for use in tests
    bytes32 public actualRegistrarRole;
    bytes32 public actualDeanRole; 
    bytes32 public actualDirectorRole;
    bytes32 public actualSignatoryRole;
    bytes32 public actualViewerRole;
    
    function setUp() public virtual {
        // Generate consistent addresses from private keys
        admin = vm.addr(adminPk);
        registrar = vm.addr(registrarPk);
        dean = vm.addr(deanPk);
        director = vm.addr(directorPk);
        student = vm.addr(studentPk);

        console.log("Admin address expected:", admin);
        console.log("Registrar address:", registrar);
        console.log("Dean address:", dean);
        console.log("Director address:", director);
        console.log("Student address:", student);

        vm.startPrank(admin);
        
        // Deploy and initialize factory
        factory = new DocumentFactory();
        factory.initialize();

        require(
            factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin),
            "Factory admin not configured correctly"
        );
        
        // Verify factory admin role
        require(
            factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin) &&
            factory.hasRole(factory.FACTORY_ADMIN_ROLE(), admin),
            "Factory admin not configured correctly"
        );

        vm.stopPrank();
        
        // Deploy institution system through factory
        vm.prank(admin);
        DocumentFactory.DeployedContracts memory contracts = factory.deployInstitutionSystem(
            INSTITUTION_NAME,
            NFT_NAME,
            NFT_SYMBOL,
            admin
        );
        
        // Connect to deployed contracts
        institutionDAO = InstitutionDAO(contracts.institutionDAO);
        signatureManager = DocumentSignatureManager(contracts.signatureManager);
        documentNFT = DocumentNFT(contracts.documentNFT);
        documentWorkflow = DocumentWorkflow(contracts.documentWorkflow);
        
        // Verify admin roles were granted correctly
        require(institutionDAO.hasRole(institutionDAO.DEFAULT_ADMIN_ROLE(), admin), "Admin missing DAO role");
        require(signatureManager.hasRole(signatureManager.DEFAULT_ADMIN_ROLE(), admin), "Admin missing signature role");
        require(documentNFT.hasRole(documentNFT.DEFAULT_ADMIN_ROLE(), admin), "Admin missing NFT role");
        require(documentWorkflow.hasRole(documentWorkflow.DEFAULT_ADMIN_ROLE(), admin), "Admin missing workflow role");
        require(documentWorkflow.hasRole(documentWorkflow.WORKFLOW_ADMIN_ROLE(), admin), "Admin missing WORKFLOW_ADMIN_ROLE");
        require(documentWorkflow.hasRole(documentWorkflow.CREATOR_ROLE(), admin), "Admin missing CREATOR_ROLE");
            
        // Setup initial data
        _setupInitialData();
    }
    
    function _setupInitialData() internal {
        vm.startPrank(admin);
        
        console.log("Current msg.sender in _setupInitialData:", msg.sender);
        console.log("Expected admin:", admin);
        
        // Create all necessary roles first
        actualRegistrarRole = institutionDAO.createRole("Registrar", "Registry staff responsible for student records");
        actualDeanRole = institutionDAO.createRole("Dean", "Academic dean with signing authority");
        actualDirectorRole = institutionDAO.createRole("Director", "Director with administrative signing authority");
        actualSignatoryRole = institutionDAO.createRole("Signatory", "Authorized to sign documents");
        actualViewerRole = institutionDAO.createRole("Viewer", "Can view documents");
        
        // DEBUG: Print created role IDs
        console.log("Created actualRegistrarRole:", vm.toString(actualRegistrarRole));
        console.log("Created actualDeanRole:", vm.toString(actualDeanRole));
        console.log("Created actualDirectorRole:", vm.toString(actualDirectorRole));
        
        // Create departments
        institutionDAO.createDepartment("Registry", registrar);
        institutionDAO.createDepartment("Deanery", dean);
        institutionDAO.createDepartment("Direction", director);
        
        // Add members with the newly created roles
        bytes32[] memory registrarRoles = new bytes32[](2);
        registrarRoles[0] = actualRegistrarRole;
        registrarRoles[1] = actualSignatoryRole;
        institutionDAO.addMember(registrar, "John Registrar", "Registry", registrarRoles);
        
        bytes32[] memory deanRoles = new bytes32[](2);
        deanRoles[0] = actualDeanRole;
        deanRoles[1] = actualSignatoryRole;
        institutionDAO.addMember(dean, "Mary Dean", "Deanery", deanRoles);
        
        bytes32[] memory directorRoles = new bytes32[](2);
        directorRoles[0] = actualDirectorRole;
        directorRoles[1] = actualSignatoryRole;
        institutionDAO.addMember(director, "Bob Director", "Direction", directorRoles);
        
        // Add student as a member for testing
        bytes32[] memory studentRoles = new bytes32[](1);
        studentRoles[0] = actualViewerRole;
        institutionDAO.addMember(student, "Test Student", "Students", studentRoles);
        
        vm.stopPrank();
    }
    
    function _createTestDocument() internal returns (uint256 tokenId) {
        vm.prank(admin);
        
        bytes32[] memory requiredRoles = new bytes32[](3);
        requiredRoles[0] = actualRegistrarRole;
        requiredRoles[1] = actualDeanRole;
        requiredRoles[2] = actualDirectorRole;
        
        tokenId = documentNFT.createDocument(
            student,
            "Test Certificate",
            "A test graduation certificate",
            "QmTestHash123",
            keccak256("test document content"),
            block.timestamp + 30 days,
            requiredRoles,
            "GRADUATION_CERTIFICATE"
        );
        
        // Create workflow template if it doesn't exist
        vm.prank(admin);
        if (documentWorkflow.getWorkflowTemplate("GRADUATION_CERTIFICATE").length == 0) {
            _createGraduationCertificateTemplate();
        }
        
        // Create workflow for the document
        vm.prank(admin);
        documentWorkflow.createDocumentWorkflow(tokenId, "GRADUATION_CERTIFICATE");

        // Verify workflow was created
        DocumentTypes.DocumentWorkflowData memory createdWorkflow = documentWorkflow.getDocumentWorkflow(tokenId);
        assertEq(createdWorkflow.documentId, tokenId, "Workflow should exist with correct documentId");
        assertGt(createdWorkflow.steps.length, 0, "Workflow should have steps");

        return tokenId;
    }
    
    function _createGraduationCertificateTemplate() internal {

        console.log("_createGraduationCertificateTemplate called by:", msg.sender);
        console.log("Admin address:", admin);
        console.log("Does msg.sender have WORKFLOW_ADMIN_ROLE:", documentWorkflow.hasRole(documentWorkflow.WORKFLOW_ADMIN_ROLE(), msg.sender));
        
        vm.startPrank(admin);

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
        
        console.log("templateRoles.length:", templateRoles.length);
        console.log("isRequired.length:", isRequired.length);
        console.log("order.length:", order.length);
        console.log("deadlines.length:", deadlines.length);
        
        documentWorkflow.createWorkflowTemplate(
            "GRADUATION_CERTIFICATE",
            templateRoles,
            isRequired,
            order,
            deadlines
        );
        vm.stopPrank();
    }
    
    function _getPrivateKey(address signer) internal view returns (uint256) {
        if (signer == admin) return adminPk;
        if (signer == registrar) return registrarPk;
        if (signer == dean) return deanPk;
        if (signer == director) return directorPk;
        if (signer == student) return studentPk;
        revert("Unknown signer");
    }

    function _signDocumentAs(
        address signer,
        uint256 tokenId,
        bytes32 role,
        bytes32 documentHash
    ) internal {
        uint256 deadline = block.timestamp + 1 days;
        
        // Create EIP-712 signature
        uint256 signerPk = _getPrivateKey(signer);
        
        bytes32 structHash = keccak256(abi.encode(
            keccak256("DocumentSignature(uint256 documentId,address signer,bytes32 role,bytes32 documentHash,uint256 deadline)"),
            tokenId,
            signer,
            role,
            documentHash,
            deadline
        ));
        
        bytes32 domainSeparator = signatureManager.domainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(signer);
        signatureManager.addSignature(tokenId, role, documentHash, deadline, signature);
    }

    function _signThroughWorkflow(
        address signer,
        uint256 tokenId,
        uint256 stepIndex,
        bytes32 documentHash
    ) internal {
    
        console.log("=== Starting _signThroughWorkflow ===");
        console.log("signer:", signer);
        console.log("tokenId:", tokenId);
        console.log("stepIndex:", stepIndex);
        
        // Get workflow details
        DocumentTypes.DocumentWorkflowData memory workflow =
            documentWorkflow.getDocumentWorkflow(tokenId);
        console.log("Got workflow, step completed:", workflow.steps[stepIndex].isCompleted);
        console.log("Current step index:", stepIndex ,"-", workflow.steps.length);
        
        require(stepIndex < workflow.steps.length, "Invalid step index");
        console.log("Passed require check");
        
        // ✅ REMOVED: Don't check completion status here - let the contract handle it
        // The contract should revert with "Step already completed" if needed
        
        uint256 deadline = workflow.steps[stepIndex].deadline;
        bytes32 role = workflow.steps[stepIndex].role;
        console.log("Got deadline and role");
        console.log("About to get private key");
        uint256 signerPk = _getPrivateKey(signer);
        console.log("PKy", signerPk);
        
        // Create EIP-712 signature
        bytes32 structHash = keccak256(abi.encode(
            keccak256("DocumentSignature(uint256 documentId,address signer,bytes32 role,bytes32 documentHash,uint256 deadline)"),
            tokenId,
            signer,
            role,
            documentHash,
            deadline
        ));
        
        bytes32 domainSeparator = signatureManager.domainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(signer);
        console.log("=== About to call completeWorkflowStep ===");
        // This call will revert with "Step already completed" if the step is already completed
        documentWorkflow.completeWorkflowStep(tokenId, stepIndex, documentHash, signature);
        console.log("=== Completed completeWorkflowStep ===");
    }
    
    function _getRoleForStep(uint256 stepIndex) internal view returns (bytes32) {
        if (stepIndex == 0) return actualRegistrarRole;
        if (stepIndex == 1) return actualDeanRole;
        if (stepIndex == 2) return actualDirectorRole;
        revert("Invalid step index");
    }
    
    function _getSignerForStep(uint256 stepIndex) internal view returns (address) {
        if (stepIndex == 0) return registrar;
        if (stepIndex == 1) return dean;
        if (stepIndex == 2) return director;
        revert("Invalid step index");
    }
}