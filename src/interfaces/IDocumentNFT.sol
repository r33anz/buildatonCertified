// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/DocumentTypes.sol";

interface IDocumentNFT {
    // Roles
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    function MINTER_ROLE() external pure returns (bytes32);
    function UPDATER_ROLE() external pure returns (bytes32);
    
    // Core functions
    function initialize(string memory _name, string memory _symbol, address _adminAddress, address _signatureManager, address _institutionDAO) external;
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    
    // Document management
    function createDocument(address _beneficiary, string memory _title, string memory _description, string memory _ipfsHash, bytes32 _documentHash, uint256 _deadline, bytes32[] memory _requiredRoles, string memory _documentType) external returns (uint256);
    function updateDocumentState(uint256 _tokenId) external;
    
    // View functions
    function getDocument(uint256 _tokenId) external view returns (DocumentTypes.Document memory);
    function getBeneficiary(uint256 _tokenId) external view returns (address);
    function getDocumentsByBeneficiary(address _beneficiary) external view returns (uint256[] memory);
    function getDocumentsByState(DocumentTypes.DocumentState _state) external view returns (uint256[] memory);
}
