// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/InstitutionDAO.sol";

contract SetupMembers is Script {
    // Cuentas predeterminadas de Anvil
    uint256 constant ADMIN_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d; // Account 1
    uint256 constant DIRECTOR_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a; // Account 2  
    uint256 constant SECRETARY_KEY = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6; // Account 3
    uint256 constant STUDENT_KEY = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a; // Account 4
    
    // Try the template address first, or update this with the correct deployed address
    address constant INSTITUTION_DAO = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    
    function run() external {
        address admin = vm.addr(ADMIN_KEY);
        address director = vm.addr(DIRECTOR_KEY);
        address secretary = vm.addr(SECRETARY_KEY);
        address student = vm.addr(STUDENT_KEY);
        
        console.log("=== SETTING UP MEMBERS FOR ANVIL ===");
        console.log("Admin:", admin);
        console.log("Director:", director);
        console.log("Secretary:", secretary);
        console.log("Student:", student);
        console.log("InstitutionDAO:", INSTITUTION_DAO);
        console.log("");
        
        // First, verify the contract exists at the address
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(INSTITUTION_DAO)
        }
        require(codeSize > 0, "No contract found at INSTITUTION_DAO address");
        
        vm.startBroadcast(ADMIN_KEY);
        
        InstitutionDAO dao = InstitutionDAO(INSTITUTION_DAO);
        
        console.log("1. Creating departments...");
        
        // Crear departamentos
        dao.createDepartment("Administracion Academica", director);
        console.log("   Created department: Administracion Academica");
        
        dao.createDepartment("Secretaria General", secretary);
        console.log("   Created department: Secretaria General");
        
        dao.createDepartment("Estudiantes", student);
        console.log("   Created department: Estudiantes");
        
        console.log("");
        console.log("2. Creating custom roles...");
        
        // Crear roles personalizados
        bytes32 directorRole = dao.createRole("Director Academico", "Autoriza documentos academicos y diplomas");
        console.log("   Created Director Role:", vm.toString(directorRole));
        
        bytes32 secretaryRole = dao.createRole("Secretario General", "Valida y certifica documentos oficiales");
        console.log("   Created Secretary Role:", vm.toString(secretaryRole));
        
        bytes32 studentRole = dao.createRole("Estudiante", "Estudiante de la institucion");
        console.log("   Created Student Role:", vm.toString(studentRole));
        
        console.log("");
        console.log("3. Adding members with roles...");
        
        // Agregar Director Académico
        bytes32[] memory directorRoles = new bytes32[](1);
        directorRoles[0] = directorRole;
        
        dao.addMember(
            director,
            "Dr. Juan Perez - Director Academico",
            "Administracion Academica",
            directorRoles
        );
        console.log("   Added Director:", director);
        
        // Agregar Secretario General  
        bytes32[] memory secretaryRoles = new bytes32[](1);
        secretaryRoles[0] = secretaryRole;
        
        dao.addMember(
            secretary,
            "Lic. Maria Rodriguez - Secretaria General", 
            "Secretaria General",
            secretaryRoles
        );
        console.log("   Added Secretary:", secretary);
        
        // Agregar Estudiante
        bytes32[] memory studentRoles = new bytes32[](1);
        studentRoles[0] = studentRole;
        
        dao.addMember(
            student,
            "Carlos Estudiantez - Estudiante de Ingenieria",
            "Estudiantes",
            studentRoles
        );
        console.log("   Added Student:", student);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== SETUP COMPLETED ===");
        console.log("Members and roles have been successfully created!");
        console.log("");
        console.log("Available roles:");
        console.log("   - Director Role:", vm.toString(directorRole));
        console.log("   - Secretary Role:", vm.toString(secretaryRole)); 
        console.log("   - Student Role:", vm.toString(studentRole));
        console.log("");
        console.log("Available members:");
        console.log("   - Admin: ", admin);
        console.log("   - Director: ", director, " (Administracion Academica)");
        console.log("   - Secretary: ", secretary, " (Secretaria General)");
        console.log("   - Student: ", student, " (Estudiantes)");
        
        // Guardar configuración de miembros
        string memory membersJson = string(
            abi.encodePacked(
                '{\n',
                '  "network": "anvil",\n',
                '  "setupAt": ', vm.toString(block.timestamp), ',\n',
                '  "contractAddresses": {\n',
                '    "institutionDAO": "', vm.toString(INSTITUTION_DAO), '"\n',
                '  },\n',
                '  "roles": {\n',
                '    "directorRole": "', vm.toString(directorRole), '",\n',
                '    "secretaryRole": "', vm.toString(secretaryRole), '",\n',
                '    "studentRole": "', vm.toString(studentRole), '"\n',
                '  },\n',
                '  "members": {\n',
                '    "admin": {\n',
                '      "address": "', vm.toString(admin), '",\n',
                '      "privateKey": "', vm.toString(ADMIN_KEY), '",\n',
                '      "name": "Admin Universidad",\n',
                '      "role": "ADMIN",\n',
                '      "department": "Administration"\n',
                '    },\n',
                '    "director": {\n',
                '      "address": "', vm.toString(director), '",\n',
                '      "privateKey": "', vm.toString(DIRECTOR_KEY), '",\n',
                '      "name": "Dr. Juan Perez",\n',
                '      "roleId": "', vm.toString(directorRole), '",\n',
                '      "department": "Administracion Academica"\n',
                '    },\n',
                '    "secretary": {\n',
                '      "address": "', vm.toString(secretary), '",\n',
                '      "privateKey": "', vm.toString(SECRETARY_KEY), '",\n',
                '      "name": "Lic. Maria Rodriguez",\n',
                '      "roleId": "', vm.toString(secretaryRole), '",\n',
                '      "department": "Secretaria General"\n',
                '    },\n',
                '    "student": {\n',
                '      "address": "', vm.toString(student), '",\n',
                '      "privateKey": "', vm.toString(STUDENT_KEY), '",\n',
                '      "name": "Carlos Estudiantez",\n',
                '      "roleId": "', vm.toString(studentRole), '",\n',
                '      "department": "Estudiantes"\n',
                '    }\n',
                '  },\n',
                '  "departments": [\n',
                '    {\n',
                '      "name": "Administracion Academica",\n',
                '      "head": "', vm.toString(director), '"\n',
                '    },\n',
                '    {\n',
                '      "name": "Secretaria General",\n',
                '      "head": "', vm.toString(secretary), '"\n',
                '    },\n',
                '    {\n',
                '      "name": "Estudiantes",\n',
                '      "head": "', vm.toString(student), '"\n',
                '    }\n',
                '  ]\n',
                '}'
            )
        );
        
        vm.writeFile("./members-config.json", membersJson);
        console.log("Members configuration saved to members-config.json");
        console.log("=====================================");
    }
}