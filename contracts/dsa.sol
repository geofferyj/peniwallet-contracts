// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
contract DSA {
    
    // struct to store the project details fee withdrawal details
    struct Project {
        address payable projectOwner;
        address projectAddress;
        uint256 projectFee;
        uint256 lastWithdrawal;
    }

    mapping(address => Project[]) public projects;

    // function to create a new project
    function createProject(address payable _projectOwner, address _projectAddress, uint256 _projectFee) public {
        Project memory newProject = Project(_projectOwner, _projectAddress, _projectFee, block.timestamp);
        projects[_projectOwner].push(newProject);
    }

    // function to get the project details
    function getProjectDetails(address _projectOwner, uint256 _index) public view returns (address payable, address, uint256, uint256) {
        Project memory project = projects[_projectOwner][_index];
        return (project.projectOwner, project.projectAddress, project.projectFee, project.lastWithdrawal);
    }

    // function to get project by address
    function getProjectByAddress(address _projectOwner, address _projectAddress) public view returns (Project memory) {
        Project memory project;
        for (uint256 i = 0; i < projects[_projectOwner].length; i++) {
            if (projects[_projectOwner][i].projectAddress == _projectAddress) {
                project = projects[_projectOwner][i];
                break;
            }
        }
        return project;
    }

    // function to get the number of projects
    function getNumberOfProjects(address _projectOwner) public view returns (uint256) {
        return projects[_projectOwner].length;
    }

    // function to update project details
    function updateProject(uint256 _projectFee) public {
        Project memory project = getProjectByAddress(msg.sender, msg.sender);
        project.projectFee += _projectFee;
    }
}