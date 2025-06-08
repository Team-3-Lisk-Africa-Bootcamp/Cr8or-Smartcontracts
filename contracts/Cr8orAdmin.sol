// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Cr8orAdmin {
    // Mapping to track admin status
    mapping(address => bool) public isAdmin;
    //array to store all admins
    address[] private adminList;

    // Events for transparency
    event AdminAdded(address indexed addedBy, address indexed newAdmin);
    event AdminRemoved(address indexed removedBy, address indexed removedAdmin);

    // Modifier to restrict to only admins
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Cr8orAdmin: Not an admin");
        _;
    }

    constructor() {
        isAdmin[msg.sender] = true; // Deployer is the first admin
        adminList.push(msg.sender);
        emit AdminAdded(address(0), msg.sender);
    }

    /// @notice Add a new admin
    /// @param newAdmin The address to grant admin rights
    function addAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Cr8orAdmin: Invalid address");
        require(!isAdmin[newAdmin], "Cr8orAdmin: Already an admin");

        isAdmin[newAdmin] = true;
        adminList.push(newAdmin);
        emit AdminAdded(msg.sender, newAdmin);
    }

    /// @notice Remove an admin
    /// @param adminToRemove The address to remove from admin list
    function removeAdmin(address adminToRemove) external onlyAdmin {
        require(adminToRemove != msg.sender, "Cr8orAdmin: Cannot remove yourself");
        require(isAdmin[adminToRemove], "Cr8orAdmin: Not an admin");

        isAdmin[adminToRemove] = false;

        // Remove from array
        for (uint256 i = 0; i < adminList.length; i++) {
            if (adminList[i] == adminToRemove) {
                adminList[i] = adminList[adminList.length - 1];
                adminList.pop();
                break;
            }
        }

        emit AdminRemoved(msg.sender, adminToRemove);
    }

    /// @notice Get full list of admins
    function listAllAdmins() external view returns (address[] memory) {
        return adminList;
    }

    /// @notice Check if an address is admin
    /// @param addr Address to check
    /// @return bool Whether the address is an admin
    function isAddressAdmin(address addr) external view returns (bool) {
        return isAdmin[addr];
    }
}
