// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract InstitutionDAO is Initializable, AccessControlUpgradeable {

    // System roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ROLE_CREATOR_ROLE = keccak256("ROLE_CREATOR_ROLE");

    struct Member {
        bool active;
        uint256 joinDate;
        string department;
        string name;
        bytes32[] assignedRoles;
    }

    struct Department {
        string name;
        address head;
        bool active;
        address[] members;
    }

    struct RoleInfo {
        string name;
        string description;
        bool active;
        uint256 createdAt;
        address createdBy;
    }

    mapping(address => Member) public members;
    mapping(string => Department) public departments;
    mapping(bytes32 => RoleInfo) public roleInfos;
    
    address[] public allMembers;
    string[] public allDepartments;
    bytes32[] public allRoles;

    event MemberAdded(address indexed member, string name, string department);
    event MemberRoleGranted(address indexed member, bytes32 indexed role);
    event MemberRoleRevoked(address indexed member, bytes32 indexed role);
    event DepartmentCreated(string name, address head);
    event RoleCreated(bytes32 indexed roleId, string name, string description, address creator);
    event RoleDeactivated(bytes32 indexed roleId);

    modifier roleExists(bytes32 _role) {
        require(roleInfos[_role].active, "Role does not exist or is inactive");
        _;
    }

    function initialize(address _admin) external initializer {
        __AccessControl_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(ROLE_CREATOR_ROLE, _admin);

        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ROLE_CREATOR_ROLE, ADMIN_ROLE);
        
        _createSystemRole(ADMIN_ROLE, "Administrator", "System administrator with full access");
        _createSystemRole(ROLE_CREATOR_ROLE, "Role Creator", "Can create and manage custom roles");
    }

    function createRole(
        string memory _roleName,
        string memory _description
    ) external onlyRole(ROLE_CREATOR_ROLE) returns (bytes32) {
        bytes32 roleId = keccak256(abi.encodePacked(_roleName, block.timestamp, msg.sender));
        
        require(!roleInfos[roleId].active, "Role ID collision");
        require(bytes(_roleName).length > 0, "Role name cannot be empty");

        roleInfos[roleId] = RoleInfo({
            name: _roleName,
            description: _description,
            active: true,
            createdAt: block.timestamp,
            createdBy: msg.sender
        });

        allRoles.push(roleId);
        _setRoleAdmin(roleId, ADMIN_ROLE);

        emit RoleCreated(roleId, _roleName, _description, msg.sender);
        return roleId;
    }

    function _createSystemRole(
        bytes32 _roleId,
        string memory _name,
        string memory _description
    ) internal {
        roleInfos[_roleId] = RoleInfo({
            name: _name,
            description: _description,
            active: true,
            createdAt: block.timestamp,
            createdBy: address(0) 
        });
        allRoles.push(_roleId);
    }

    function deactivateRole(bytes32 _roleId) external onlyRole(ADMIN_ROLE) {
        require(_roleId != ADMIN_ROLE && _roleId != ROLE_CREATOR_ROLE, "Cannot deactivate system roles");
        require(roleInfos[_roleId].active, "Role already inactive");
        
        roleInfos[_roleId].active = false;
        emit RoleDeactivated(_roleId);
    }

    function addMember(
        address _member,
        string memory _name,
        string memory _department,
        bytes32[] memory _roles
    ) external onlyRole(ADMIN_ROLE) {
        require(!members[_member].active, "Member already exists");
        
        for (uint i = 0; i < _roles.length; i++) {
            require(roleInfos[_roles[i]].active, "One or more roles are inactive");
        }
        
        members[_member] = Member({
            active: true,
            joinDate: block.timestamp,
            department: _department,
            name: _name,
            assignedRoles: _roles
        });

        for (uint i = 0; i < _roles.length; i++) {
            _grantRole(_roles[i], _member);
        }

        allMembers.push(_member);
        departments[_department].members.push(_member);
        
        emit MemberAdded(_member, _name, _department);
    }

    function createDepartment(
        string memory _name,
        address _head
    ) external onlyRole(ADMIN_ROLE) {
        require(!departments[_name].active, "Department exists");
        
        departments[_name] = Department({
            name: _name,
            head: _head,
            active: true,
            members: new address[](0)
        });
        
        allDepartments.push(_name);
        emit DepartmentCreated(_name, _head);
    }

    function grantMemberRole(
        address _member, 
        bytes32 _role
    ) external roleExists(_role) onlyRole(ADMIN_ROLE) {
        require(members[_member].active, "Member not found");
        
        _grantRole(_role, _member);
        members[_member].assignedRoles.push(_role);
        emit MemberRoleGranted(_member, _role);
    }

    function revokeMemberRole(
        address _member, 
        bytes32 _role
    ) external roleExists(_role) onlyRole(ADMIN_ROLE) {
        require(members[_member].active, "Member not found");
        
        _revokeRole(_role, _member);
        
        bytes32[] storage roles = members[_member].assignedRoles;
        for (uint i = 0; i < roles.length; i++) {
            if (roles[i] == _role) {
                roles[i] = roles[roles.length - 1];
                roles.pop();
                break;
            }
        }
        
        emit MemberRoleRevoked(_member, _role);
    }

    // === VIEW FUNCTIONS ===

    function getRoleInfo(bytes32 _roleId) external view returns (RoleInfo memory) {
        return roleInfos[_roleId];
    }

    function getAllRoles() external view returns (bytes32[] memory) {
        return allRoles;
    }

    function getActiveRoles() external view returns (bytes32[] memory) {
        uint256 activeCount = 0;
       
        for (uint i = 0; i < allRoles.length; i++) {
            if (roleInfos[allRoles[i]].active) {
                activeCount++;
            }
        }
        
        bytes32[] memory activeRoles = new bytes32[](activeCount);
        uint256 index = 0;
        
        for (uint i = 0; i < allRoles.length; i++) {
            if (roleInfos[allRoles[i]].active) {
                activeRoles[index] = allRoles[i];
                index++;
            }
        }
        
        return activeRoles;
    }

    function getMemberRoles(address _member) external view returns (bytes32[] memory) {
        return members[_member].assignedRoles;
    }

    function getDepartmentMembers(string memory _department) external view returns (address[] memory) {
        return departments[_department].members;
    }

    function getAllMembers() external view returns (address[] memory) {
        return allMembers;
    }

    function getAllDepartments() external view returns (string[] memory) {
        return allDepartments;
    }

    function getRolesByCreator(address _creator) external view returns (bytes32[] memory) {
        uint256 count = 0;
        
        for (uint i = 0; i < allRoles.length; i++) {
            if (roleInfos[allRoles[i]].createdBy == _creator) {
                count++;
            }
        }
        
        bytes32[] memory creatorRoles = new bytes32[](count);
        uint256 index = 0;
        
        for (uint i = 0; i < allRoles.length; i++) {
            if (roleInfos[allRoles[i]].createdBy == _creator) {
                creatorRoles[index] = allRoles[i];
                index++;
            }
        }
        
        return creatorRoles;
    }

    function isMember(address _member) external view returns (bool) {
        return members[_member].active;
    }
}