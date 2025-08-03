// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IInstitutionDAO {
    // System roles
    function ADMIN_ROLE() external pure returns (bytes32);
    function ROLE_CREATOR_ROLE() external pure returns (bytes32);
    
    // Core functions
    function initialize(address _admin) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function isMember(address _member) external view returns (bool);
    
    // Role management
    function createRole(string memory _roleName, string memory _description) external returns (bytes32);
    function grantMemberRole(address _member, bytes32 _role) external;
    function revokeMemberRole(address _member, bytes32 _role) external;
    
    // Member management
    function addMember(address _member, string memory _name, string memory _department, bytes32[] memory _roles) external;
    
    // View functions
    function getAllRoles() external view returns (bytes32[] memory);
    function getMemberRoles(address _member) external view returns (bytes32[] memory);
    function getAllMembers() external view returns (address[] memory);
}