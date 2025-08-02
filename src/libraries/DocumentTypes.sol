// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library DocumentTypes {
    enum DocumentState { DRAFT, PENDING_SIGNATURES, PARTIALLY_SIGNED, COMPLETED, CANCELLED }
    
    struct Document {
        string title;
        string description;
        string ipfsHash;
        bytes32 documentHash;
        DocumentState state;
        uint256 createdAt;
        uint256 deadline;
        address creator;
        bytes32[] requiredRoles;
        uint256 requiredSignatures;
        string documentType;
        string metadata;
    }
    
    struct DocumentSignature {
        uint256 documentId;
        address signer;
        uint256 timestamp;
        bytes32 role;
        bytes32 documentHash;
        uint256 deadline;
        bool isValid;
    }
    
    struct WorkflowStep {
        bytes32 role;
        bool isRequired;
        uint256 order;
        uint256 deadline;
        bool isCompleted;
        address completedBy;
        uint256 completedAt;
    }
    
    struct DocumentWorkflowData {
        uint256 documentId;
        WorkflowStep[] steps;
        uint256 currentStep;
        bool isCompleted;
        uint256 createdAt;
        string workflowType;
    }
}