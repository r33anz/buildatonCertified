// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/InstitutionDAO.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InstitutionDAOTest is Test {
    InstitutionDAO public dao;
    InstitutionDAO public implementation;
    
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public roleCreator = makeAddr("roleCreator");
    
    bytes32 public customRole1;

    function setUp() public {
        implementation = new InstitutionDAO();
        
        bytes memory initData = abi.encodeWithSelector(
            InstitutionDAO.initialize.selector,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        dao = InstitutionDAO(address(proxy));
        
        vm.startPrank(admin);
        dao.grantRole(dao.ROLE_CREATOR_ROLE(), roleCreator);
        vm.stopPrank();
    }
    
    function test_Initialize() public {
        assertTrue(dao.hasRole(dao.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(dao.hasRole(dao.ADMIN_ROLE(), admin));
        assertTrue(dao.hasRole(dao.ROLE_CREATOR_ROLE(), admin));
    }
    
    function test_CreateRole() public {
        vm.prank(roleCreator);
        bytes32 roleId = dao.createRole("Developer", "Software developer role");
        
        InstitutionDAO.RoleInfo memory roleInfo = dao.getRoleInfo(roleId);
        assertEq(roleInfo.name, "Developer");
        assertTrue(roleInfo.active);
        customRole1 = roleId;
    }

    function test_CreateDepartment() public {
        vm.prank(admin);
        dao.createDepartment("Engineering", user1);
        
        // The public mapping getter only returns the basic fields, not the array
        // departments mapping returns (name, head, active) - arrays are not returned by public getters
        (string memory name, address head, bool active) = dao.departments("Engineering");
        assertEq(name, "Engineering");
        assertEq(head, user1);
        assertTrue(active);
    }
    
    function test_AddMember() public {
        // Setup
        vm.prank(admin);
        dao.createDepartment("Engineering", user1);
        
        vm.prank(roleCreator);
        customRole1 = dao.createRole("Developer", "Software developer");
        
        bytes32[] memory roles = new bytes32[](1);
        roles[0] = customRole1;
        
        // Add member
        vm.prank(admin);
        dao.addMember(user1, "Alice Developer", "Engineering", roles);
        
        // The public mapping getter only returns the basic fields, not the array
        // members mapping returns (active, joinDate, department, name) - arrays are not returned by public getters
        (bool active, uint256 joinDate, string memory dept, string memory name) = dao.members(user1);
        assertTrue(active);
        assertGt(joinDate, 0);
        assertEq(dept, "Engineering");
        assertEq(name, "Alice Developer");
        
        // Use the getter function to check assigned roles
        bytes32[] memory assignedRoles = dao.getMemberRoles(user1);
        assertEq(assignedRoles.length, 1);
        assertEq(assignedRoles[0], customRole1);
        
        // Verify role assignment
        assertTrue(dao.hasRole(customRole1, user1));
    }

    function test_GrantRole() public {
        // Setup member without roles
        vm.prank(admin);
        dao.createDepartment("Engineering", user1);
        
        bytes32[] memory emptyRoles = new bytes32[](0);
        vm.prank(admin);
        dao.addMember(user1, "Alice", "Engineering", emptyRoles);
        
        // Create and grant role
        vm.prank(roleCreator);
        customRole1 = dao.createRole("Developer", "Software developer");
        
        vm.prank(admin);
        dao.grantMemberRole(user1, customRole1);
        
        assertTrue(dao.hasRole(customRole1, user1));
    }

    function test_RevokeRole() public {
        // Setup member with role
        vm.prank(admin);
        dao.createDepartment("Engineering", user1);
        
        vm.prank(roleCreator);
        customRole1 = dao.createRole("Developer", "Software developer");
        
        bytes32[] memory roles = new bytes32[](1);
        roles[0] = customRole1;
        
        vm.prank(admin);
        dao.addMember(user1, "Alice", "Engineering", roles);
        
        // Verify role is granted
        assertTrue(dao.hasRole(customRole1, user1));
        
        // Revoke role
        vm.prank(admin);
        dao.revokeMemberRole(user1, customRole1);
        
        assertFalse(dao.hasRole(customRole1, user1));
    }

    function test_DeactivateRole() public {
        vm.prank(roleCreator);
        customRole1 = dao.createRole("TempRole", "Temporary role");
        
        vm.prank(admin);
        dao.deactivateRole(customRole1);
        
        InstitutionDAO.RoleInfo memory roleInfo = dao.getRoleInfo(customRole1);
        assertFalse(roleInfo.active);
    }

    function test_GetRolesByCreator() public {
        vm.prank(roleCreator);
        customRole1 = dao.createRole("Role1", "First role");
        
        bytes32[] memory creatorRoles = dao.getRolesByCreator(roleCreator);
        assertEq(creatorRoles.length, 1);
        assertEq(creatorRoles[0], customRole1);
    }

    function test_GetActiveRoles() public {
        bytes32[] memory activeRoles = dao.getActiveRoles();
        assertEq(activeRoles.length, 2); // 2 system roles initially
        
        vm.prank(roleCreator);
        dao.createRole("NewRole", "New role");
        
        activeRoles = dao.getActiveRoles();
        assertEq(activeRoles.length, 3); // 2 system + 1 custom
    }

    function test_AccessControl() public {
        // Only role creators can create roles
        vm.prank(user1);
        vm.expectRevert();
        dao.createRole("Unauthorized", "Should fail");
        
        // Only admins can add members
        vm.prank(user1);
        bytes32[] memory roles = new bytes32[](0);
        vm.expectRevert();
        dao.addMember(user1, "Unauthorized", "Engineering", roles);
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        dao.initialize(admin);
    }

    function test_CannotDeactivateSystemRoles() public {
        bytes32 ADMIN_ROLE_HASH = keccak256("ADMIN_ROLE");
        bytes32 CREATOR_ROLE_HASH = keccak256("ROLE_CREATOR_ROLE");

        vm.prank(admin);
        vm.expectRevert("Cannot deactivate system roles");
        dao.deactivateRole(ADMIN_ROLE_HASH);
        
        vm.prank(admin);
        vm.expectRevert("Cannot deactivate system roles");
        dao.deactivateRole(CREATOR_ROLE_HASH);
    }

    function test_CannotCreateDuplicateDepartment() public {
        vm.startPrank(admin);
        dao.createDepartment("Engineering", user1);
        
        vm.expectRevert("Department exists");
        dao.createDepartment("Engineering", user1);
        vm.stopPrank();
    }
}