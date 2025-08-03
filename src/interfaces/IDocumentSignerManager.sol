// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/DocumentTypes.sol";

interface IDocumentSignatureManager {
    // Roles
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function MANAGER_ROLE() external pure returns (bytes32);
    function WORKFLOW_ROLE() external pure returns (bytes32);
    
    // Core functions
    function initialize(address _institutionDAO, address _adminAddress, string memory _name, string memory _version) external;
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    function grantWorkflowRole(address _workflowContract) external;
    
    // Signature management
    function addSignature(uint256 _documentId, bytes32 _role, bytes32 _documentHash, uint256 _deadline, bytes memory _signature) external;
    function addSignatureForSigner(uint256 _documentId, address _signer, bytes32 _role, bytes32 _documentHash, uint256 _deadline, bytes memory _signature) external;
    
    // View functions
    function getDocumentSignatures(uint256 _documentId) external view returns (DocumentTypes.DocumentSignature[] memory);
    function getSignatureCount(uint256 _documentId) external view returns (uint256);
    function verifyExternalSignature(uint256 _documentId, address _signer, bytes32 _role, bytes32 _documentHash, uint256 _deadline, bytes memory _signature) external view returns (bool);
}