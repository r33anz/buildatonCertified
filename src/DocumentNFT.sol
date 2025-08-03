// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {InstitutionDAO} from "./InstitutionDAO.sol";
import {DocumentSignatureManager} from "./DocumentSignatureManager.sol";

import "./libraries/DocumentTypes.sol";

contract DocumentNFT is Initializable, ERC721Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    mapping(uint256 => DocumentTypes.Document) public documents;
    mapping(uint256 => string) public tokenURIs;
    mapping(uint256 => address) public documentBeneficiary; 

    uint256 private _tokenIdCounter;

    DocumentSignatureManager public signatureManager;
    InstitutionDAO public institutionDAO;

    event DocumentCreated(uint256 indexed tokenId, string title, address creator, address beneficiary);
    event DocumentStateChanged(uint256 indexed tokenId, DocumentTypes.DocumentState newState);
    event DocumentMetadataUpdated(uint256 indexed tokenId);

    function initialize(
        string memory _name,
        string memory _symbol,
        address _adminAddress,
        address _signatureManager,
        address _institutionDAO
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __AccessControl_init();
        __ReentrancyGuard_init();
        
        signatureManager = DocumentSignatureManager(_signatureManager);
        institutionDAO = InstitutionDAO(_institutionDAO);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _grantRole(MINTER_ROLE, _adminAddress);
        _grantRole(UPDATER_ROLE, _adminAddress);
    }

    function createDocument(
        address _beneficiary, 
        string memory _title,
        string memory _description,
        string memory _ipfsHash,
        bytes32 _documentHash,
        uint256 _deadline,
        bytes32[] memory _requiredRoles,
        string memory _documentType
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(institutionDAO.isMember(_beneficiary), "Beneficiary must be a member of the institution");
        
        uint256 tokenId = _tokenIdCounter++;
        
        documents[tokenId] = DocumentTypes.Document({
            title: _title,
            description: _description,
            ipfsHash: _ipfsHash,
            documentHash: _documentHash,
            state: DocumentTypes.DocumentState.PENDING_SIGNATURES,
            createdAt: block.timestamp,
            deadline: _deadline,
            creator: msg.sender,
            requiredRoles: _requiredRoles,
            requiredSignatures: _requiredRoles.length,
            documentType: _documentType,
            metadata: ""
        });

        // Guardar el beneficiario
        documentBeneficiary[tokenId] = _beneficiary;

        // Mintear el NFT directamente al beneficiario
        _safeMint(_beneficiary, tokenId);
        _updateMetadata(tokenId);

        emit DocumentCreated(tokenId, _title, msg.sender, _beneficiary);
        emit DocumentStateChanged(tokenId, DocumentTypes.DocumentState.PENDING_SIGNATURES);
        
        return tokenId;
    }

    function updateDocumentState(uint256 _tokenId) external onlyRole(UPDATER_ROLE) {
        require(_exists(_tokenId), "Document does not exist");
        
        DocumentTypes.Document storage doc = documents[_tokenId];
        uint256 signaturesReceived = signatureManager.getSignatureCount(_tokenId);
        
        DocumentTypes.DocumentState newState;
        
        if (signaturesReceived == 0) {
            newState = DocumentTypes.DocumentState.PENDING_SIGNATURES;
        } else if (signaturesReceived < doc.requiredSignatures) {
            newState = DocumentTypes.DocumentState.PARTIALLY_SIGNED;
        } else {
            newState = DocumentTypes.DocumentState.COMPLETED;
        }
        
        if (block.timestamp > doc.deadline && newState != DocumentTypes.DocumentState.COMPLETED) {
            newState = DocumentTypes.DocumentState.CANCELLED;
        }
        
        doc.state = newState;
        _updateMetadata(_tokenId);
        
        emit DocumentStateChanged(_tokenId, newState);
    }

    function _updateMetadata(uint256 _tokenId) internal {
        DocumentTypes.Document memory doc = documents[_tokenId];
        uint256 signaturesReceived = signatureManager.getSignatureCount(_tokenId);
        address beneficiary = documentBeneficiary[_tokenId];
        
        string memory metadata = string(abi.encodePacked(
            '{"name": "', doc.title, '",',
            '"description": "', doc.description, '",',
            '"image": "ipfs://', doc.ipfsHash, '",',
            '"attributes": [',
                '{"trait_type": "Document Type", "value": "', doc.documentType, '"},',
                '{"trait_type": "State", "value": "', _stateToString(doc.state), '"},',
                '{"trait_type": "Beneficiary", "value": "', _addressToString(beneficiary), '"},',
                '{"trait_type": "Creator", "value": "', _addressToString(doc.creator), '"},',
                '{"trait_type": "Signatures Received", "value": ', _toString(signaturesReceived), '},',
                '{"trait_type": "Required Signatures", "value": ', _toString(doc.requiredSignatures), '},',
                '{"trait_type": "Created At", "value": ', _toString(doc.createdAt), '},',
                '{"trait_type": "Deadline", "value": ', _toString(doc.deadline), '}',
            ']}'
        ));
        
        documents[_tokenId].metadata = metadata;
        emit DocumentMetadataUpdated(_tokenId);
    }

    // Nueva función para obtener el beneficiario de un documento
    function getBeneficiary(uint256 _tokenId) external view returns (address) {
        require(_exists(_tokenId), "Document does not exist");
        return documentBeneficiary[_tokenId];
    }

    // Nueva función para obtener documentos por beneficiario
    function getDocumentsByBeneficiary(address _beneficiary) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (_exists(i) && documentBeneficiary[i] == _beneficiary) {
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (_exists(i) && documentBeneficiary[i] == _beneficiary) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(documents[_tokenId].metadata))
        ));
    }

    function getDocument(uint256 _tokenId) external view returns (DocumentTypes.Document memory) {
        require(_exists(_tokenId), "Document does not exist");
        return documents[_tokenId];
    }

    function getDocumentsByState(DocumentTypes.DocumentState _state) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (_exists(i) && documents[i].state == _state) {
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (_exists(i) && documents[i].state == _state) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }

    function _stateToString(DocumentTypes.DocumentState _state) internal pure returns (string memory) {
        if (_state == DocumentTypes.DocumentState.DRAFT) return "Draft";
        if (_state == DocumentTypes.DocumentState.PENDING_SIGNATURES) return "Pending Signatures";
        if (_state == DocumentTypes.DocumentState.PARTIALLY_SIGNED) return "Partially Signed";
        if (_state == DocumentTypes.DocumentState.COMPLETED) return "Completed";
        if (_state == DocumentTypes.DocumentState.CANCELLED) return "Cancelled";
        return "Unknown";
    }

    function _toString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) return "0";
        
        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }
        
        return string(buffer);
    }

    function _addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function _base64Encode(bytes memory _data) internal pure returns (string memory) {
        if (_data.length == 0) return "";
        
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        string memory result = new string(4 * ((_data.length + 2) / 3));
        
        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            
            for {
                let dataPtr := _data
                let endPtr := add(dataPtr, mload(_data))
            } lt(dataPtr, endPtr) {
                dataPtr := add(dataPtr, 3)
            } {
                let input := mload(dataPtr)
                
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }
            
            switch mod(mload(_data), 3)
            case 1 {
                mstore8(sub(resultPtr, 2), 0x3d)
                mstore8(sub(resultPtr, 1), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }
        
        return result;
    }

    // Override required functions
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override {
        // Solo permitir transferencias desde/hacia address(0) (mint/burn)
        // Los documentos institucionales no deberían ser transferibles
        require(from == address(0) || to == address(0), "Document NFTs are non-transferable");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}