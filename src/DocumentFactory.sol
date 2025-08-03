// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Solo importamos interfaces para reducir el tamaño
interface IInstitutionDAO {
    function initialize(address _admin) external;
}

interface IDocumentSignatureManager {
    function initialize(address _institutionDAO, address _adminAddress, string memory _name, string memory _version) external;
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    function grantWorkflowRole(address _workflowContract) external;
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function MANAGER_ROLE() external pure returns (bytes32);
}

interface IDocumentNFT {
    function initialize(string memory _name, string memory _symbol, address _adminAddress, address _signatureManager, address _institutionDAO) external;
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function UPDATER_ROLE() external pure returns (bytes32);
    function MINTER_ROLE() external pure returns (bytes32);
}

interface IDocumentWorkflow {
    function initialize(address _adminAddress, address _documentNFT, address _signatureManager, address _institutionDAO) external;
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function CREATOR_ROLE() external pure returns (bytes32);
    function WORKFLOW_ADMIN_ROLE() external pure returns (bytes32);
}

contract DocumentFactory is Initializable, AccessControlUpgradeable {
    
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    struct DeployedContracts {
        address institutionDAO;
        address signatureManager;
        address documentNFT;
        address documentWorkflow;
        uint256 deployedAt;
        bool isActive;
    }

    // Templates para cloning (se setean una vez)
    address public institutionDAOTemplate;
    address public signatureManagerTemplate;
    address public documentNFTTemplate;
    address public documentWorkflowTemplate;

    mapping(string => DeployedContracts) public institutionContracts;
    string[] public allInstitutions;

    event InstitutionDeployed(string indexed institutionName, address indexed deployer);
    event ContractsLinked(string indexed institutionName);
    event TemplatesSet(address dao, address signature, address nft, address workflow);

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ADMIN_ROLE, msg.sender);
    }

    // Setear templates una sola vez (contratos ya desplegados)
    function setTemplates(
        address _institutionDAOTemplate,
        address _signatureManagerTemplate,
        address _documentNFTTemplate,
        address _documentWorkflowTemplate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        institutionDAOTemplate = _institutionDAOTemplate;
        signatureManagerTemplate = _signatureManagerTemplate;
        documentNFTTemplate = _documentNFTTemplate;
        documentWorkflowTemplate = _documentWorkflowTemplate;
        
        emit TemplatesSet(_institutionDAOTemplate, _signatureManagerTemplate, _documentNFTTemplate, _documentWorkflowTemplate);
    }

    // Desplegar sistema completo usando clones
    function deployInstitutionSystem(
        string memory _institutionName,
        string memory _nftName,
        string memory _nftSymbol,
        address _adminAddress
    ) external onlyRole(FACTORY_ADMIN_ROLE) returns (DeployedContracts memory) {
        require(institutionContracts[_institutionName].institutionDAO == address(0), "Institution already deployed");
        require(_templatesSet(), "Templates not set");

        // 1. Clone InstitutionDAO
        address institutionDAO = _cloneContract(institutionDAOTemplate, _institutionName, "DAO");
        IInstitutionDAO(institutionDAO).initialize(_adminAddress);

        // 2. Clone DocumentSignatureManager
        address signatureManager = _cloneContract(signatureManagerTemplate, _institutionName, "SIG");
        IDocumentSignatureManager sigManager = IDocumentSignatureManager(signatureManager);
        sigManager.initialize(
            institutionDAO,
            address(this),
            string(abi.encodePacked(_institutionName, " Documents")),
            "1"
        );
        sigManager.grantRole(sigManager.DEFAULT_ADMIN_ROLE(), _adminAddress);

        // 3. Clone DocumentNFT
        address documentNFT = _cloneContract(documentNFTTemplate, _institutionName, "NFT");
        IDocumentNFT nft = IDocumentNFT(documentNFT);
        nft.initialize(_nftName, _nftSymbol, address(this), signatureManager, institutionDAO);
        nft.grantRole(nft.DEFAULT_ADMIN_ROLE(), _adminAddress);

        // 4. Clone DocumentWorkflow
        address documentWorkflow = _cloneContract(documentWorkflowTemplate, _institutionName, "WF");
        IDocumentWorkflow workflow = IDocumentWorkflow(documentWorkflow);
        workflow.initialize(address(this), documentNFT, signatureManager, institutionDAO);
        workflow.grantRole(workflow.DEFAULT_ADMIN_ROLE(), _adminAddress);

        // 5. Grant workflow role
        sigManager.grantWorkflowRole(documentWorkflow);

        // 6. Setup permissions
        _setupPermissions(nft, sigManager, workflow, _adminAddress);

        // 7. Renounce factory admin roles
        sigManager.renounceRole(sigManager.DEFAULT_ADMIN_ROLE(), address(this));
        nft.renounceRole(nft.DEFAULT_ADMIN_ROLE(), address(this));
        workflow.renounceRole(workflow.DEFAULT_ADMIN_ROLE(), address(this));

        // 8. Store contracts
        DeployedContracts memory contracts = DeployedContracts({
            institutionDAO: institutionDAO,
            signatureManager: signatureManager,
            documentNFT: documentNFT,
            documentWorkflow: documentWorkflow,
            deployedAt: block.timestamp,
            isActive: true
        });

        institutionContracts[_institutionName] = contracts;
        allInstitutions.push(_institutionName);

        emit InstitutionDeployed(_institutionName, msg.sender);
        emit ContractsLinked(_institutionName);

        return contracts;
    }

    function _cloneContract(address template, string memory institutionName, string memory contractType) internal returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(institutionName, contractType, block.timestamp));
        
        // Minimal proxy pattern (EIP-1167) - muy eficiente en gas
        bytes memory bytecode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            template,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        address clone;
        assembly {
            clone := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(clone != address(0), "Clone deployment failed");
        return clone;
    }

    function _setupPermissions(
        IDocumentNFT _nft,
        IDocumentSignatureManager _sigManager,
        IDocumentWorkflow _workflow,
        address _admin
    ) internal {
        // Grant roles to workflow and signature manager
        _nft.grantRole(_nft.UPDATER_ROLE(), address(_workflow));
        _nft.grantRole(_nft.UPDATER_ROLE(), address(_sigManager));
        _nft.grantRole(_nft.MINTER_ROLE(), address(_workflow));
        _nft.grantRole(_nft.MINTER_ROLE(), _admin);

        _sigManager.grantRole(_sigManager.MANAGER_ROLE(), address(_workflow));
        _sigManager.grantRole(_sigManager.MANAGER_ROLE(), _admin);

        _workflow.grantRole(_workflow.CREATOR_ROLE(), _admin);
        _workflow.grantRole(_workflow.WORKFLOW_ADMIN_ROLE(), _admin);
    }

    function _templatesSet() internal view returns (bool) {
        return institutionDAOTemplate != address(0) &&
               signatureManagerTemplate != address(0) &&
               documentNFTTemplate != address(0) &&
               documentWorkflowTemplate != address(0);
    }

    // View functions
    function getInstitutionContracts(string memory _institutionName) external view returns (DeployedContracts memory) {
        return institutionContracts[_institutionName];
    }

    function getAllInstitutions() external view returns (string[] memory) {
        return allInstitutions;
    }

    function deactivateInstitution(string memory _institutionName) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(institutionContracts[_institutionName].institutionDAO != address(0), "Institution not found");
        institutionContracts[_institutionName].isActive = false;
    }

    function reactivateInstitution(string memory _institutionName) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(institutionContracts[_institutionName].institutionDAO != address(0), "Institution not found");
        institutionContracts[_institutionName].isActive = true;
    }

    // Predict clone addresses (útil para frontend)
    function predictCloneAddress(string memory institutionName, string memory contractType, address template) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(institutionName, contractType, block.timestamp));
        
        bytes memory bytecode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            template,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(bytecode)
        )))));
    }
}