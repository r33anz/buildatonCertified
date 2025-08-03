// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {DocumentNFT} from "./DocumentNFT.sol";
import {DocumentSignatureManager} from "./DocumentSignatureManager.sol";
import {InstitutionDAO} from "./InstitutionDAO.sol";
import {DocumentWorkflow} from "./DocumentWorkflow.sol";


import "./libraries/DocumentTypes.sol";

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

    mapping(string => DeployedContracts) public institutionContracts;
    string[] public allInstitutions;

    event InstitutionDeployed(string indexed institutionName, address indexed deployer);
    event ContractsLinked(string indexed institutionName);

    function initialize() external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ADMIN_ROLE, msg.sender);
    }

    function deployInstitutionSystem(
        string memory _institutionName,
        string memory _nftName,
        string memory _nftSymbol,
        address _adminAddress
    ) external onlyRole(FACTORY_ADMIN_ROLE) returns (DeployedContracts memory) {
        require(institutionContracts[_institutionName].institutionDAO == address(0), "Institution already deployed");

        // 1. Deploy InstitutionDAO
        InstitutionDAO institutionDAO = new InstitutionDAO();
        institutionDAO.initialize(_adminAddress);

        // 2. Deploy DocumentSignatureManager
        DocumentSignatureManager signatureManager = new DocumentSignatureManager();
        signatureManager.initialize(
            address(institutionDAO),
            address(this), 
            string(abi.encodePacked(_institutionName, " Documents")),
            "1"
        );

        // Grant admin role to the intended admin but DON'T renounce yet
        signatureManager.grantRole(signatureManager.DEFAULT_ADMIN_ROLE(), _adminAddress);

        // 3. Deploy DocumentNFT
        DocumentNFT documentNFT = new DocumentNFT();
        documentNFT.initialize(
            _nftName,
            _nftSymbol,
            address(this), 
            address(signatureManager),
            address(institutionDAO)
        );

        documentNFT.grantRole(documentNFT.DEFAULT_ADMIN_ROLE(), _adminAddress);

        // 4. Deploy DocumentWorkflow
        DocumentWorkflow documentWorkflow = new DocumentWorkflow();
        documentWorkflow.initialize(
            address(this), 
            address(documentNFT),
            address(signatureManager),
            address(institutionDAO)
        );

        documentWorkflow.grantRole(documentWorkflow.DEFAULT_ADMIN_ROLE(), _adminAddress);
        
        signatureManager.grantWorkflowRole(address(documentWorkflow));

        // 5. Configurar permisos cruzados BEFORE renouncing admin roles
        _setupCrossContractPermissions(
            institutionDAO,
            signatureManager,
            documentNFT,
            documentWorkflow,
            _adminAddress
        );

        signatureManager.renounceRole(signatureManager.DEFAULT_ADMIN_ROLE(), address(this));
        documentNFT.renounceRole(documentNFT.DEFAULT_ADMIN_ROLE(), address(this));
        documentWorkflow.renounceRole(documentWorkflow.DEFAULT_ADMIN_ROLE(), address(this));

        DeployedContracts memory contracts = DeployedContracts({
            institutionDAO: address(institutionDAO),
            signatureManager: address(signatureManager),
            documentNFT: address(documentNFT),
            documentWorkflow: address(documentWorkflow),
            deployedAt: block.timestamp,
            isActive: true
        });

        institutionContracts[_institutionName] = contracts;
        allInstitutions.push(_institutionName);

        emit InstitutionDeployed(_institutionName, msg.sender);
        emit ContractsLinked(_institutionName);

        return contracts;
    }

    function _setupCrossContractPermissions(
        InstitutionDAO _institutionDAO,
        DocumentSignatureManager _signatureManager,
        DocumentNFT _documentNFT,
        DocumentWorkflow _documentWorkflow,
        address _admin
    ) internal {
        _documentNFT.grantRole(_documentNFT.UPDATER_ROLE(), address(_documentWorkflow));
        _documentNFT.grantRole(_documentNFT.UPDATER_ROLE(), address(_signatureManager));
        _documentNFT.grantRole(_documentNFT.MINTER_ROLE(), address(_documentWorkflow));
        _documentNFT.grantRole(_documentNFT.MINTER_ROLE(), _admin);

        _signatureManager.grantRole(_signatureManager.MANAGER_ROLE(), address(_documentWorkflow));
        _signatureManager.grantRole(_signatureManager.MANAGER_ROLE(), _admin);

        _documentWorkflow.grantRole(_documentWorkflow.CREATOR_ROLE(), _admin);
        _documentWorkflow.grantRole(_documentWorkflow.WORKFLOW_ADMIN_ROLE(), _admin);
    }

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
}