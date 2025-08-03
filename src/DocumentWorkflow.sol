// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {DocumentNFT} from "./DocumentNFT.sol";
import {DocumentSignatureManager} from "./DocumentSignatureManager.sol";
import {InstitutionDAO} from "./InstitutionDAO.sol";

import "./libraries/DocumentTypes.sol";

contract DocumentWorkflow is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    
    bytes32 public constant WORKFLOW_ADMIN_ROLE = keccak256("WORKFLOW_ADMIN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    mapping(uint256 => DocumentTypes.DocumentWorkflowData) public documentWorkflows;
    mapping(string => DocumentTypes.WorkflowStep[]) public workflowTemplates;
    
    DocumentNFT public documentNFT;
    DocumentSignatureManager public signatureManager;
    InstitutionDAO public institutionDAO;

    event WorkflowCreated(uint256 indexed documentId, string workflowType);
    event WorkflowStepCompleted(uint256 indexed documentId, uint256 stepIndex, address completedBy);
    event WorkflowCompleted(uint256 indexed documentId);
    event WorkflowTemplateCreated(string workflowType);

    function initialize(
        address _adminAddress,
        address _documentNFT,
        address _signatureManager,
        address _institutionDAO
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        
        documentNFT = DocumentNFT(_documentNFT);
        signatureManager = DocumentSignatureManager(_signatureManager);
        institutionDAO = InstitutionDAO(_institutionDAO);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _grantRole(WORKFLOW_ADMIN_ROLE, _adminAddress);
        _grantRole(CREATOR_ROLE, _adminAddress);
    }

    /// 🧩 Esta función permite crear plantillas desde el frontend (dashboard)
    function createWorkflowTemplate(
        string memory _workflowType,
        bytes32[] memory roles,
        bool[] memory isRequired,
        uint256[] memory order,
        uint256[] memory deadline
    ) external onlyRole(WORKFLOW_ADMIN_ROLE) {
        require(
            roles.length == isRequired.length &&
            roles.length == order.length &&
            roles.length == deadline.length,
            "Input array length mismatch"
        );

        delete workflowTemplates[_workflowType];

        for (uint i = 0; i < roles.length; i++) {
            DocumentTypes.WorkflowStep memory step = DocumentTypes.WorkflowStep({
                role: roles[i],
                isRequired: isRequired[i],
                order: order[i],
                deadline: deadline[i],
                isCompleted: false,
                completedBy: address(0),
                completedAt: 0
            });

            workflowTemplates[_workflowType].push(step);
        }

        emit WorkflowTemplateCreated(_workflowType);
    }

    function createDocumentWorkflow(
        uint256 _documentId,
        string memory _workflowType
    ) external onlyRole(CREATOR_ROLE) {
        require(workflowTemplates[_workflowType].length > 0, "Workflow template not found");
        require(documentWorkflows[_documentId].documentId == 0, "Workflow already exists");
        
        DocumentTypes.DocumentWorkflowData storage workflow = documentWorkflows[_documentId];
        workflow.documentId = _documentId;
        workflow.currentStep = 0;
        workflow.isCompleted = false;
        workflow.createdAt = block.timestamp;
        workflow.workflowType = _workflowType;
        
        DocumentTypes.WorkflowStep[] memory templateSteps = workflowTemplates[_workflowType];
        for (uint i = 0; i < templateSteps.length; i++) {
            workflow.steps.push(templateSteps[i]);
        }
        
        emit WorkflowCreated(_documentId, _workflowType);
    }

    function completeWorkflowStep(
        uint256 _documentId,
        uint256 _stepIndex,
        bytes32 _documentHash,
        bytes memory _signature
    ) external {
        DocumentTypes.DocumentWorkflowData storage workflow = documentWorkflows[_documentId];
        require(_stepIndex < workflow.steps.length, "Invalid step index");
        require(!workflow.steps[_stepIndex].isCompleted, "Step already completed");
        require(_stepIndex == workflow.currentStep, "Must complete steps in order");
        
        DocumentTypes.WorkflowStep storage step = workflow.steps[_stepIndex];
        
        require(institutionDAO.hasRole(step.role, msg.sender), "Invalid role for step");
        require(block.timestamp <= step.deadline, "Step deadline passed");
        
        signatureManager.addSignatureForSigner(
            _documentId,
            msg.sender,
            step.role,
            _documentHash,
            step.deadline,
            _signature
        );
        
        step.isCompleted = true;
        step.completedBy = msg.sender;
        step.completedAt = block.timestamp;
        
        workflow.currentStep++;
        
        if (workflow.currentStep >= workflow.steps.length) {
            workflow.isCompleted = true;
            documentNFT.updateDocumentState(_documentId);
            emit WorkflowCompleted(_documentId);
        }
        
        emit WorkflowStepCompleted(_documentId, _stepIndex, msg.sender);
    }

    function getDocumentWorkflow(uint256 _documentId) external view returns (DocumentTypes.DocumentWorkflowData memory) {
        return documentWorkflows[_documentId];
    }

    function getWorkflowTemplate(string memory _workflowType) external view returns (DocumentTypes.WorkflowStep[] memory) {
        return workflowTemplates[_workflowType];
    }

    function getCurrentStep(uint256 _documentId) external view returns (DocumentTypes.WorkflowStep memory) {
        DocumentTypes.DocumentWorkflowData storage workflow = documentWorkflows[_documentId];
        require(workflow.documentId != 0, "Workflow not found");

        if (workflow.currentStep >= workflow.steps.length) {
            return DocumentTypes.WorkflowStep({
                role: bytes32(0),
                isRequired: false,
                order: 0,
                deadline: 0,
                isCompleted: true,
                completedBy: address(0),
                completedAt: 0
            });
        }

        return workflow.steps[workflow.currentStep];
    }
}
