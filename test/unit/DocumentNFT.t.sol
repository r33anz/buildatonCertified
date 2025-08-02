// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/DocumentNFT.sol";
import "../../src/DocumentSignatureManager.sol";
import "../../src/InstitutionDAO.sol";
import "../../src/libraries/DocumentTypes.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DocumentNFTTest is Test {
    DocumentNFT public documentNFT;
    DocumentNFT public nftImplementation;
    DocumentSignatureManager public signatureManager;
    DocumentSignatureManager public signatureImplementation;
    InstitutionDAO public dao;
    InstitutionDAO public daoImplementation;
    
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public updater = makeAddr("updater");
    address public student = makeAddr("student");
    address public professor = makeAddr("professor");
    address public dean = makeAddr("dean");
    address public unauthorized = makeAddr("unauthorized");
    
    bytes32 public studentRole;
    bytes32 public professorRole;
    bytes32 public deanRole;
    
    // Test data
    string constant NFT_NAME = "Institution Certificates";
    string constant NFT_SYMBOL = "CERT";
    string constant DOCUMENT_TITLE = "Computer Science Degree";
    string constant DOCUMENT_DESCRIPTION = "Bachelor's degree in Computer Science";
    string constant IPFS_HASH = "QmTestHash123";
    bytes32 constant DOCUMENT_HASH = keccak256("degree certificate content");
    string constant DOCUMENT_TYPE = "Academic Certificate";
    uint256 deadline;

    function setUp() public {
        deadline = block.timestamp + 30 days;
        
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
            "DocumentSignatureManager",
            "1"
        );
        ERC1967Proxy signatureProxy = new ERC1967Proxy(
            address(signatureImplementation), 
            signatureInitData
        );
        signatureManager = DocumentSignatureManager(address(signatureProxy));
        
        // Deploy DocumentNFT
        nftImplementation = new DocumentNFT();
        bytes memory nftInitData = abi.encodeWithSelector(
            DocumentNFT.initialize.selector,
            NFT_NAME,
            NFT_SYMBOL,
            admin,
            address(signatureManager),
            address(dao)
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImplementation),
            nftInitData
        );
        documentNFT = DocumentNFT(address(nftProxy));
        
        // Setup DAO and roles
        vm.startPrank(admin);
        
        // Grant role creator to admin
        dao.grantRole(dao.ROLE_CREATOR_ROLE(), admin);
        
        // Create roles
        studentRole = dao.createRole("Student", "University Student");
        professorRole = dao.createRole("Professor", "University Professor");
        deanRole = dao.createRole("Dean", "Faculty Dean");
        
        // Create department
        dao.createDepartment("Computer Science", dean);
        
        // Add members
        bytes32[] memory studentRoles = new bytes32[](1);
        studentRoles[0] = studentRole;
        dao.addMember(student, "Alice Student", "Computer Science", studentRoles);
        
        bytes32[] memory profRoles = new bytes32[](1);
        profRoles[0] = professorRole;
        dao.addMember(professor, "Bob Professor", "Computer Science", profRoles);
        
        bytes32[] memory deanRoles = new bytes32[](1);
        deanRoles[0] = deanRole;
        dao.addMember(dean, "Charlie Dean", "Computer Science", deanRoles);
        
        // Grant NFT roles
        documentNFT.grantRole(documentNFT.MINTER_ROLE(), minter);
        documentNFT.grantRole(documentNFT.UPDATER_ROLE(), updater);
        
        vm.stopPrank();
    }
    
    function test_Initialize() public {
        assertEq(documentNFT.name(), NFT_NAME);
        assertEq(documentNFT.symbol(), NFT_SYMBOL);
        assertTrue(documentNFT.hasRole(documentNFT.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(documentNFT.hasRole(documentNFT.MINTER_ROLE(), admin));
        assertTrue(documentNFT.hasRole(documentNFT.UPDATER_ROLE(), admin));
        assertEq(address(documentNFT.signatureManager()), address(signatureManager));
        assertEq(address(documentNFT.institutionDAO()), address(dao));
    }
    
    function test_CreateDocument_Success() public {
        bytes32[] memory requiredRoles = new bytes32[](2);
        requiredRoles[0] = professorRole;
        requiredRoles[1] = deanRole;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student, // beneficiary
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Verify NFT was minted to student
        assertEq(documentNFT.ownerOf(tokenId), student);
        assertEq(documentNFT.balanceOf(student), 1);
        
        // Verify beneficiary mapping
        assertEq(documentNFT.getBeneficiary(tokenId), student);
        
        // Verify document data
        DocumentTypes.Document memory doc = documentNFT.getDocument(tokenId);
        assertEq(doc.title, DOCUMENT_TITLE);
        assertEq(doc.description, DOCUMENT_DESCRIPTION);
        assertEq(doc.ipfsHash, IPFS_HASH);
        assertEq(doc.documentHash, DOCUMENT_HASH);
        assertEq(doc.creator, minter);
        assertEq(doc.requiredSignatures, 2);
        assertEq(doc.documentType, DOCUMENT_TYPE);
        assertTrue(doc.state == DocumentTypes.DocumentState.PENDING_SIGNATURES);
    }
    
    function test_CreateDocument_OnlyMinter() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.prank(unauthorized);
        vm.expectRevert();
        documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
    }
    
    function test_CreateDocument_InvalidBeneficiary() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.prank(minter);
        vm.expectRevert("Invalid beneficiary address");
        documentNFT.createDocument(
            address(0), // invalid address
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
    }
    
    function test_CreateDocument_BeneficiaryNotMember() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.prank(minter);
        vm.expectRevert("Beneficiary must be a member of the institution");
        documentNFT.createDocument(
            unauthorized, // not a member
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
    }
    
    function test_UpdateDocumentState_PendingSignatures() public {
        // Create document
        bytes32[] memory requiredRoles = new bytes32[](2);
        requiredRoles[0] = professorRole;
        requiredRoles[1] = deanRole;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Update state (no signatures yet)
        vm.prank(updater);
        documentNFT.updateDocumentState(tokenId);
        
        DocumentTypes.Document memory doc = documentNFT.getDocument(tokenId);
        assertTrue(doc.state == DocumentTypes.DocumentState.PENDING_SIGNATURES);
    }
    
    function test_UpdateDocumentState_Cancelled() public {
        
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        uint256 pastDeadline = block.timestamp + 1 hours;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            pastDeadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Advance time past deadline
        vm.warp(block.timestamp + 2 hours);
        
        // Update state
        vm.prank(updater);
        documentNFT.updateDocumentState(tokenId);
        
        DocumentTypes.Document memory doc = documentNFT.getDocument(tokenId);
        assertTrue(doc.state == DocumentTypes.DocumentState.CANCELLED);
    }
    
    function test_UpdateDocumentState_OnlyUpdater() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        vm.prank(unauthorized);
        vm.expectRevert();
        documentNFT.updateDocumentState(tokenId);
    }
    
    function test_GetDocumentsByBeneficiary() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        // Create multiple documents for the same student
        vm.startPrank(minter);
        uint256 tokenId1 = documentNFT.createDocument(
            student,
            "Degree 1",
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        uint256 tokenId2 = documentNFT.createDocument(
            student,
            "Degree 2",
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Create document for different student
        documentNFT.createDocument(
            professor,
            "Professor Cert",
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        vm.stopPrank();
        
        // Get documents by beneficiary
        uint256[] memory studentDocs = documentNFT.getDocumentsByBeneficiary(student);
        uint256[] memory profDocs = documentNFT.getDocumentsByBeneficiary(professor);
        
        assertEq(studentDocs.length, 2);
        assertEq(profDocs.length, 1);
        assertEq(studentDocs[0], tokenId1);
        assertEq(studentDocs[1], tokenId2);
    }
    
    function test_GetDocumentsByState() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.startPrank(minter);
        uint256 tokenId1 = documentNFT.createDocument(
            student,
            "Doc 1",
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        uint256 tokenId2 = documentNFT.createDocument(
            professor,
            "Doc 2",
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        vm.stopPrank();
        
        uint256[] memory pendingDocs = documentNFT.getDocumentsByState(
            DocumentTypes.DocumentState.PENDING_SIGNATURES
        );
        
        assertEq(pendingDocs.length, 2);
        assertTrue(pendingDocs[0] == tokenId1 || pendingDocs[1] == tokenId1);
        assertTrue(pendingDocs[0] == tokenId2 || pendingDocs[1] == tokenId2);
    }
    
    function test_TokenURI() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        string memory uri = documentNFT.tokenURI(tokenId);
        
        // Verify it starts with data:application/json;base64,
        assertTrue(bytes(uri).length > 0);
        
        // The URI should contain base64 encoded JSON
        bytes memory prefix = bytes("data:application/json;base64,");
        bytes memory uriBytes = bytes(uri);
        
        for (uint i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i]);
        }
    }
    
    function test_TokenURI_NonexistentToken() public {
        vm.expectRevert("URI query for nonexistent token");
        documentNFT.tokenURI(999);
    }
    
    function test_NonTransferable() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Try to transfer (should fail)
        vm.prank(student);
        vm.expectRevert("Document NFTs are non-transferable");
        documentNFT.transferFrom(student, professor, tokenId);
    }
    
    function test_Events() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        // Test DocumentCreated event
        vm.expectEmit(true, false, false, true);
        emit DocumentCreated(0, DOCUMENT_TITLE, minter, student);
        
        // Test DocumentStateChanged event
        vm.expectEmit(true, false, false, true);
        emit DocumentStateChanged(0, DocumentTypes.DocumentState.PENDING_SIGNATURES);
        
        vm.prank(minter);
        documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
    }
    
    function test_SupportsInterface() public {
        // Test ERC721 interface
        assertTrue(documentNFT.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(documentNFT.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(documentNFT.supportsInterface(0x7965db0b)); // AccessControl
        assertTrue(documentNFT.supportsInterface(0x01ffc9a7)); // ERC165
    }
    
    function test_CannotInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        documentNFT.initialize(
            "Test",
            "TEST",
            admin,
            address(signatureManager),
            address(dao)
        );
    }
    
    function test_GetDocument_NonexistentToken() public {
        vm.expectRevert("Document does not exist");
        documentNFT.getDocument(999);
    }
    
    function test_GetBeneficiary_NonexistentToken() public {
        vm.expectRevert("Document does not exist");
        documentNFT.getBeneficiary(999);
    }
    
    function test_UpdateDocumentState_NonexistentToken() public {
        vm.prank(updater);
        vm.expectRevert("Document does not exist");
        documentNFT.updateDocumentState(999);
    }
    
    function test_Integration_WithSignatures() public {
        // Setup signers
        (address signer1, uint256 signer1Key) = makeAddrAndKey("signer1");
        (address signer2, uint256 signer2Key) = makeAddrAndKey("signer2");
        
        // Add signers to DAO
        vm.startPrank(admin);
        bytes32[] memory signer1Roles = new bytes32[](1);
        signer1Roles[0] = professorRole;
        dao.addMember(signer1, "Professor 1", "Computer Science", signer1Roles);
        
        bytes32[] memory signer2Roles = new bytes32[](1);
        signer2Roles[0] = deanRole;
        dao.addMember(signer2, "Dean 1", "Computer Science", signer2Roles);
        
        // Grant workflow role to test contract (to simulate workflow)
        signatureManager.grantWorkflowRole(address(this));
        vm.stopPrank();
        
        // Create document
        bytes32[] memory requiredRoles = new bytes32[](2);
        requiredRoles[0] = professorRole;
        requiredRoles[1] = deanRole;
        
        vm.prank(minter);
        uint256 tokenId = documentNFT.createDocument(
            student,
            DOCUMENT_TITLE,
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Verify initial state
        DocumentTypes.Document memory doc = documentNFT.getDocument(tokenId);
        assertTrue(doc.state == DocumentTypes.DocumentState.PENDING_SIGNATURES);
        
        // Add first signature
        bytes memory signature1 = _createValidSignature(
            tokenId,
            signer1,
            professorRole,
            DOCUMENT_HASH,
            deadline,
            signer1Key
        );
        
        vm.prank(signer1);
        signatureManager.addSignature(
            tokenId,
            professorRole,
            DOCUMENT_HASH,
            deadline,
            signature1
        );
        
        // Update document state
        vm.prank(updater);
        documentNFT.updateDocumentState(tokenId);
        
        // Should be partially signed
        doc = documentNFT.getDocument(tokenId);
        assertTrue(doc.state == DocumentTypes.DocumentState.PARTIALLY_SIGNED);
        
        // Add second signature
        bytes memory signature2 = _createValidSignature(
            tokenId,
            signer2,
            deanRole,
            DOCUMENT_HASH,
            deadline,
            signer2Key
        );
        
        vm.prank(signer2);
        signatureManager.addSignature(
            tokenId,
            deanRole,
            DOCUMENT_HASH,
            deadline,
            signature2
        );
        
        // Update document state
        vm.prank(updater);
        documentNFT.updateDocumentState(tokenId);
        
        // Should be completed
        doc = documentNFT.getDocument(tokenId);
        assertTrue(doc.state == DocumentTypes.DocumentState.COMPLETED);
        
        // Verify signature count
        assertEq(signatureManager.getSignatureCount(tokenId), 2);
    }
    
    function test_MultipleCertificatesForSameStudent() public {
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.startPrank(minter);
        
        // Create multiple certificates for the same student
        uint256 tokenId1 = documentNFT.createDocument(
            student,
            "Bachelor's Degree",
            "Computer Science Bachelor's Degree",
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            "Academic Certificate"
        );
        
        uint256 tokenId2 = documentNFT.createDocument(
            student,
            "Achievement Award",
            "Outstanding Student Award",
            "QmAnotherHash",
            keccak256("award content"),
            deadline,
            requiredRoles,
            "Achievement"
        );
        
        uint256 tokenId3 = documentNFT.createDocument(
            student,
            "Course Completion",
            "Advanced Programming Course",
            "QmCourseHash",
            keccak256("course content"),
            deadline,
            requiredRoles,
            "Course Certificate"
        );
        
        vm.stopPrank();
        
        // Verify student owns all certificates
        assertEq(documentNFT.balanceOf(student), 3);
        assertEq(documentNFT.ownerOf(tokenId1), student);
        assertEq(documentNFT.ownerOf(tokenId2), student);
        assertEq(documentNFT.ownerOf(tokenId3), student);
        
        // Verify documents by beneficiary
        uint256[] memory studentDocs = documentNFT.getDocumentsByBeneficiary(student);
        assertEq(studentDocs.length, 3);
        
        // Verify each document has correct data
        DocumentTypes.Document memory doc1 = documentNFT.getDocument(tokenId1);
        DocumentTypes.Document memory doc2 = documentNFT.getDocument(tokenId2);
        DocumentTypes.Document memory doc3 = documentNFT.getDocument(tokenId3);
        
        assertEq(doc1.title, "Bachelor's Degree");
        assertEq(doc2.title, "Achievement Award");
        assertEq(doc3.title, "Course Completion");
        
        assertEq(doc1.documentType, "Academic Certificate");
        assertEq(doc2.documentType, "Achievement");
        assertEq(doc3.documentType, "Course Certificate");
    }
    
    function test_DifferentStudentsDifferentCertificates() public {
        // Add another student
        vm.startPrank(admin);
        address student2 = makeAddr("student2");
        bytes32[] memory studentRoles = new bytes32[](1);
        studentRoles[0] = studentRole;
        dao.addMember(student2, "Bob Student", "Computer Science", studentRoles);
        vm.stopPrank();
        
        bytes32[] memory requiredRoles = new bytes32[](1);
        requiredRoles[0] = professorRole;
        
        vm.startPrank(minter);
        
        // Create certificate for first student
        uint256 tokenId1 = documentNFT.createDocument(
            student,
            "Alice's Degree",
            DOCUMENT_DESCRIPTION,
            IPFS_HASH,
            DOCUMENT_HASH,
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        // Create certificate for second student
        uint256 tokenId2 = documentNFT.createDocument(
            student2,
            "Bob's Degree",
            DOCUMENT_DESCRIPTION,
            "QmBobHash",
            keccak256("bob's content"),
            deadline,
            requiredRoles,
            DOCUMENT_TYPE
        );
        
        vm.stopPrank();
        
        // Verify ownership
        assertEq(documentNFT.ownerOf(tokenId1), student);
        assertEq(documentNFT.ownerOf(tokenId2), student2);
        assertEq(documentNFT.balanceOf(student), 1);
        assertEq(documentNFT.balanceOf(student2), 1);
        
        // Verify beneficiary mappings
        assertEq(documentNFT.getBeneficiary(tokenId1), student);
        assertEq(documentNFT.getBeneficiary(tokenId2), student2);
        
        // Verify documents by beneficiary
        uint256[] memory student1Docs = documentNFT.getDocumentsByBeneficiary(student);
        uint256[] memory student2Docs = documentNFT.getDocumentsByBeneficiary(student2);
        
        assertEq(student1Docs.length, 1);
        assertEq(student2Docs.length, 1);
        assertEq(student1Docs[0], tokenId1);
        assertEq(student2Docs[0], tokenId2);
    }
    
    // Helper function to create valid EIP-712 signatures
    function _createValidSignature(
        uint256 documentId,
        address signer,
        bytes32 role,
        bytes32 documentHash,
        uint256 _deadline,
        uint256 signerKey
    ) internal view returns (bytes memory) {
        bytes32 DOCUMENT_SIGNATURE_TYPEHASH = keccak256(
            "DocumentSignature(uint256 documentId,address signer,bytes32 role,bytes32 documentHash,uint256 deadline)"
        );
        
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
    event DocumentCreated(uint256 indexed tokenId, string title, address creator, address beneficiary);
    event DocumentStateChanged(uint256 indexed tokenId, DocumentTypes.DocumentState newState);
    event DocumentMetadataUpdated(uint256 indexed tokenId);
}