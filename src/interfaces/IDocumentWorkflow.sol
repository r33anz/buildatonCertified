// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/DocumentTypes.sol";

interface IDocumentWorkflow {
    // Roles
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function WORKFLOW_ADMIN_ROLE() external pure returns (bytes32);
    function CREATOR_ROLE() external pure returns (bytes32);
    
    // Core functions
    function initialize(address _adminAddress, address _documentNFT, address _signatureManager, address _institutionDAO) external;
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    
    // Workflow management
    function createWorkflowTemplate(string memory _workflowType, bytes32[] memory roles, bool[] memory isRequired, uint256[] memory order, uint256[] memory deadline) external;
    function createDocumentWorkflow(uint256 _documentId, string memory _workflowType) external;
    function completeWorkflowStep(uint256 _documentId, uint256 _stepIndex, bytes32 _documentHash, bytes memory _signature) external;
    
    // View functions
    function getDocumentWorkflow(uint256 _documentId) external view returns (DocumentTypes.DocumentWorkflowData memory);
    function getWorkflowTemplate(string memory _workflowType) external view returns (DocumentTypes.WorkflowStep[] memory);
    function getCurrentStep(uint256 _documentId) external view returns (DocumentTypes.WorkflowStep memory);
}