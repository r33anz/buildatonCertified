// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/DocumentSignatureManager.sol";
import "../../src/InstitutionDAO.sol";
import "../../src/libraries/DocumentTypes.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DocumentSignatureManagerTest is Test {
    DocumentSignatureManager public signatureManager;
    DocumentSignatureManager public signatureImplementation;
    InstitutionDAO public dao;
    InstitutionDAO public daoImplementation;
    
    address public admin = makeAddr("admin");
    address public manager = makeAddr("manager");
    address public workflowContract = makeAddr("workflowContract");
    address public unauthorizedUser = makeAddr("unauthorizedUser");

    address public signer1;
    uint256 public signer1Key;

    address public signer2;
    uint256 public signer2Key;
    
    bytes32 public developerRole;
    bytes32 public managerRole;
    
    // Test data
    uint256 public constant DOCUMENT_ID = 1;
    bytes32 public constant DOCUMENT_HASH = keccak256("test document content");
    uint256 public deadline;
    
    // EIP-712 domain separator and type hash
    string constant NAME = "DocumentSignatureManager";
    string constant VERSION = "1";
    bytes32 constant DOCUMENT_SIGNATURE_TYPEHASH = keccak256(
        "DocumentSignature(uint256 documentId,address signer,bytes32 role,bytes32 documentHash,uint256 deadline)"
    );

    function setUp() public {
        (signer1, signer1Key) = makeAddrAndKey("signer1");
        (signer2, signer2Key) = makeAddrAndKey("signer2");

        deadline = block.timestamp + 1 days;
        
        // Deploy InstitutionDAO
        daoImplementation = new InstitutionDAO();
        bytes memory daoInitData = abi.encodeWithSelector(
            InstitutionDAO.initialize.selector,
            admin
        );
        ERC1967Proxy daoProxy = new ERC1967Proxy(address(daoImplementation), daoInitData);
        dao = InstitutionDAO(address(daoProxy));
        
        // Deploy DocumentSignatureManager
        signatureImplementation = new DocumentSignatureManager();
        bytes memory signatureInitData = abi.encodeWithSelector(
            DocumentSignatureManager.initialize.selector,
            address(dao),
            admin,
            NAME,
            VERSION
        );
        ERC1967Proxy signatureProxy = new ERC1967Proxy(
            address(signatureImplementation), 
            signatureInitData
        );
        signatureManager = DocumentSignatureManager(address(signatureProxy));
        
        // Setup DAO: create roles and add members
        vm.startPrank(admin);
        
        // Grant role creator to admin
        dao.grantRole(dao.ROLE_CREATOR_ROLE(), admin);
        
        // Create custom roles
        developerRole = dao.createRole("Developer", "Software Developer");
        managerRole = dao.createRole("Manager", "Department Manager");
        
        // Create department
        dao.createDepartment("Engineering", manager);
        
        // Add members with roles
        bytes32[] memory signer1Roles = new bytes32[](1);
        signer1Roles[0] = developerRole;
        dao.addMember(signer1, "Alice Developer", "Engineering", signer1Roles);
        
        bytes32[] memory signer2Roles = new bytes32[](1);
        signer2Roles[0] = managerRole;
        dao.addMember(signer2, "Bob Manager", "Engineering", signer2Roles);
        
        // Grant workflow role to workflow contract
        signatureManager.grantWorkflowRole(workflowContract);
        
        vm.stopPrank();
    }
    
    function test_Initialize() public {
        assertTrue(signatureManager.hasRole(signatureManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(signatureManager.hasRole(signatureManager.MANAGER_ROLE(), admin));
        assertEq(address(signatureManager.institutionDAO()), address(dao));
    }
    
    function test_GrantWorkflowRole() public {
        address newWorkflow = makeAddr("newWorkflow");
        
        vm.prank(admin);
        signatureManager.grantWorkflowRole(newWorkflow);
        
        assertTrue(signatureManager.hasRole(signatureManager.WORKFLOW_ROLE(), newWorkflow));
    }
    
    function test_GrantWorkflowRole_OnlyAdmin() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        signatureManager.grantWorkflowRole(unauthorizedUser);
    }
    
    function test_AddSignature_Success() public {
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key
        );
        
        vm.prank(signer1);
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
        
        // Verify signature was added
        DocumentTypes.DocumentSignature[] memory signatures = signatureManager.getDocumentSignatures(DOCUMENT_ID);
        assertEq(signatures.length, 1);
        assertEq(signatures[0].signer, signer1);
        assertEq(signatures[0].role, developerRole);
        assertEq(signatures[0].documentHash, DOCUMENT_HASH);
        assertTrue(signatures[0].isValid);
        
        // Verify mappings
        assertTrue(signatureManager.hasSignerSigned(DOCUMENT_ID, signer1));
        assertTrue(signatureManager.hasRoleSigned(DOCUMENT_ID, developerRole));
        assertEq(signatureManager.signatureCount(DOCUMENT_ID), 1);
    }
    
    function test_AddSignature_InvalidRole() public {
        bytes32 invalidRole = keccak256("INVALID_ROLE");
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            invalidRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key  // Fixed: use signer1Key instead of signer1
        );
        
        vm.prank(signer1);
        vm.expectRevert("Invalid role for signer");
        signatureManager.addSignature(
            DOCUMENT_ID,
            invalidRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
    }
    
    function test_AddSignature_ExpiredDeadline() public {
        uint256 expiredDeadline = block.timestamp - 1;
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            expiredDeadline,
            signer1Key  // Fixed: use signer1Key instead of signer1
        );
        
        vm.prank(signer1);
        vm.expectRevert("Signature deadline passed");
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            expiredDeadline,
            signature
        );
    }
    
    function test_AddSignature_AlreadySigned() public {
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key  // Fixed: use signer1Key instead of signer1
        );
        
        // First signature
        vm.prank(signer1);
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
        
        // Try to sign again
        vm.prank(signer1);
        vm.expectRevert("Already signed");
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
    }
    
    function test_AddSignature_InvalidSignature() public {
        // Create signature with wrong private key
        bytes memory invalidSignature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer2Key // Fixed: use signer2Key instead of signer2
        );
        
        vm.prank(signer1);
        vm.expectRevert("Invalid signature");
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            invalidSignature
        );
    }
    
    function test_AddSignatureForSigner_Success() public {
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key
        );
        
        vm.prank(workflowContract);
        signatureManager.addSignatureForSigner(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
        
        // Verify signature was added
        DocumentTypes.DocumentSignature[] memory signatures = signatureManager.getDocumentSignatures(DOCUMENT_ID);
        assertEq(signatures.length, 1);
        assertEq(signatures[0].signer, signer1);
        assertTrue(signatureManager.hasSignerSigned(DOCUMENT_ID, signer1));
    }
    
    function test_AddSignatureForSigner_OnlyWorkflow() public {
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key  // Fixed: use signer1Key instead of signer1
        );
        
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        signatureManager.addSignatureForSigner(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
    }
    
    function test_MultipleSignatures() public {
        // Signer1 signs with developer role
        bytes memory signature1 = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key
        );
        
        vm.prank(signer1);
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature1  // Fixed: use signature1 instead of signer1Key
        );
        
        // Signer2 signs with manager role
        bytes memory signature2 = _createValidSignature(
            DOCUMENT_ID,
            signer2,
            managerRole,
            DOCUMENT_HASH,
            deadline,
            signer2Key
        );
        
        vm.prank(signer2);
        signatureManager.addSignature(
            DOCUMENT_ID,
            managerRole,
            DOCUMENT_HASH,
            deadline,
            signature2
        );
        
        // Verify both signatures
        DocumentTypes.DocumentSignature[] memory signatures = signatureManager.getDocumentSignatures(DOCUMENT_ID);
        assertEq(signatures.length, 2);
        assertEq(signatureManager.signatureCount(DOCUMENT_ID), 2);
        
        assertTrue(signatureManager.hasSignerSigned(DOCUMENT_ID, signer1));
        assertTrue(signatureManager.hasSignerSigned(DOCUMENT_ID, signer2));
        assertTrue(signatureManager.hasRoleSigned(DOCUMENT_ID, developerRole));
        assertTrue(signatureManager.hasRoleSigned(DOCUMENT_ID, managerRole));
    }
    
    function test_VerifyExternalSignature() public {
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key  // Fixed: use signer1Key instead of signer1
        );
        
        bool isValid = signatureManager.verifyExternalSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
        
        assertTrue(isValid);
        
        // Test invalid signature
        bytes memory invalidSignature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer2Key // Fixed: use signer2Key instead of signer2
        );
        
        bool isInvalid = signatureManager.verifyExternalSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            invalidSignature
        );
        
        assertFalse(isInvalid);
    }
    
    function test_GetSignatureCount() public {
        assertEq(signatureManager.getSignatureCount(DOCUMENT_ID), 0);
        
        // Add one signature
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key
        );
        
        vm.prank(signer1);
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
        
        assertEq(signatureManager.getSignatureCount(DOCUMENT_ID), 1);
    }
    
    function test_DomainSeparator() public {
        bytes32 domainSeparator = signatureManager.domainSeparator();
        assertTrue(domainSeparator != bytes32(0));
    }
    
    function test_CannotInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        signatureManager.initialize(address(dao), admin, NAME, VERSION);
    }
    
    function test_Events() public {
        bytes memory signature = _createValidSignature(
            DOCUMENT_ID,
            signer1,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key
        );
        
        vm.expectEmit(true, true, true, true);
        emit SignatureAdded(DOCUMENT_ID, signer1, developerRole);
        
        vm.expectEmit(true, true, true, true);
        emit SignatureVerified(DOCUMENT_ID, signer1, true);
        
        vm.prank(signer1);
        signatureManager.addSignature(
            DOCUMENT_ID,
            developerRole,
            DOCUMENT_HASH,
            deadline,
            signature
        );
    }
    
    // Helper function to create valid EIP-712 signatures
    function _createValidSignature(
        uint256 documentId,
        address signer,
        bytes32 role,
        bytes32 documentHash,
        uint256 _deadline,
        uint256 signerKey // Use the private key, not the address
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(
            DOCUMENT_SIGNATURE_TYPEHASH,
            documentId,
            signer,
            role,
            documentHash,
            _deadline
        ));

        bytes32 domainSeparator = signatureManager.domainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        return abi.encodePacked(r, s, v);
    }

    
    // Define events for testing
    event SignatureAdded(uint256 indexed documentId, address indexed signer, bytes32 role);
    event SignatureVerified(uint256 indexed documentId, address indexed signer, bool isValid);
}