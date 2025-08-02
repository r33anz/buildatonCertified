// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {InstitutionDAO} from "./InstitutionDAO.sol";
import "./libraries/DocumentTypes.sol";

contract DocumentSignatureManager is Initializable, EIP712Upgradeable, AccessControlUpgradeable {
    using ECDSAUpgradeable for bytes32;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant WORKFLOW_ROLE = keccak256("WORKFLOW_ROLE");
    
    // TypeHash para EIP-712
    bytes32 private constant DOCUMENT_SIGNATURE_TYPEHASH = keccak256(
        "DocumentSignature(uint256 documentId,address signer,bytes32 role,bytes32 documentHash,uint256 deadline)"
    );

    // Mappings
    mapping(uint256 => DocumentTypes.DocumentSignature[]) public documentSignatures;
    mapping(uint256 => mapping(address => bool)) public hasSignerSigned;
    mapping(uint256 => mapping(bytes32 => bool)) public hasRoleSigned;
    mapping(uint256 => uint256) public signatureCount;

    InstitutionDAO public institutionDAO;

    event SignatureAdded(uint256 indexed documentId, address indexed signer, bytes32 role);
    event SignatureVerified(uint256 indexed documentId, address indexed signer, bool isValid);

    function initialize(
        address _institutionDAO,
        address _adminAddress,
        string memory _name,
        string memory _version
    ) external initializer {
        __EIP712_init(_name, _version);
        __AccessControl_init();
        
        institutionDAO = InstitutionDAO(_institutionDAO);
        _grantRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _grantRole(MANAGER_ROLE, _adminAddress);

    }

    function grantWorkflowRole(address _workflowContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(WORKFLOW_ROLE, _workflowContract);
    }

    function addSignature(
        uint256 _documentId,
        bytes32 _role,
        bytes32 _documentHash,
        uint256 _deadline,
        bytes memory _signature
    ) external {
        _addSignature(_documentId, msg.sender, _role, _documentHash, _deadline, _signature);
    }

    function addSignatureForSigner(
        uint256 _documentId,
        address _signer,
        bytes32 _role,
        bytes32 _documentHash,
        uint256 _deadline,
        bytes memory _signature
    ) external onlyRole(WORKFLOW_ROLE) {
        _addSignature(_documentId, _signer, _role, _documentHash, _deadline, _signature);
    }

    function _addSignature(
        uint256 _documentId,
        address _signer,
        bytes32 _role,
        bytes32 _documentHash,
        uint256 _deadline,
        bytes memory _signature
    ) internal {
        require(block.timestamp <= _deadline, "Signature deadline passed");
        require(!hasSignerSigned[_documentId][_signer], "Already signed");
        require(institutionDAO.hasRole(_role, _signer), "Invalid role for signer");

        bool isValid = _verifySignature(
            _documentId,
            _signer,
            _role,
            _documentHash,
            _deadline,
            _signature
        );
        
        require(isValid, "Invalid signature");

        DocumentTypes.DocumentSignature memory newSignature = DocumentTypes.DocumentSignature({
            documentId: _documentId,
            signer: _signer,
            timestamp: block.timestamp,
            role: _role,
            documentHash: _documentHash,
            deadline: _deadline,
            isValid: isValid
        });

        documentSignatures[_documentId].push(newSignature);
        hasSignerSigned[_documentId][_signer] = true;
        hasRoleSigned[_documentId][_role] = true;
        signatureCount[_documentId]++;

        emit SignatureAdded(_documentId, _signer, _role);
        emit SignatureVerified(_documentId, _signer, isValid);
    }

    function _verifySignature(
        uint256 _documentId,
        address _signer,
        bytes32 _role,
        bytes32 _documentHash,
        uint256 _deadline,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            DOCUMENT_SIGNATURE_TYPEHASH,
            _documentId,
            _signer,
            _role,
            _documentHash,
            _deadline
        ));

        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = digest.recover(_signature);
        
        return recoveredSigner == _signer;
    }

    function getDocumentSignatures(uint256 _documentId) external view returns (DocumentTypes.DocumentSignature[] memory) {
        return documentSignatures[_documentId];
    }

    function getSignatureCount(uint256 _documentId) external view returns (uint256) {
        return signatureCount[_documentId];
    }

    function verifyExternalSignature(
        uint256 _documentId,
        address _signer,
        bytes32 _role,
        bytes32 _documentHash,
        uint256 _deadline,
        bytes memory _signature
    ) external view returns (bool) {
        return _verifySignature(_documentId, _signer, _role, _documentHash, _deadline, _signature);
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

}