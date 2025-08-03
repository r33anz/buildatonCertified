// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDocumentFactory {
    struct DeployedContracts {
        address institutionDAO;
        address signatureManager;
        address documentNFT;
        address documentWorkflow;
        uint256 deployedAt;
        bool isActive;
    }
    
    // Roles
    function FACTORY_ADMIN_ROLE() external pure returns (bytes32);
    
    // Core functions
    function initialize() external;
    function deployInstitutionSystem(string memory _institutionName, string memory _nftName, string memory _nftSymbol, address _adminAddress) external returns (DeployedContracts memory);
    
    // View functions
    function getInstitutionContracts(string memory _institutionName) external view returns (DeployedContracts memory);
    function getAllInstitutions() external view returns (string[] memory);
    
    // Management
    function deactivateInstitution(string memory _institutionName) external;
    function reactivateInstitution(string memory _institutionName) external;
}