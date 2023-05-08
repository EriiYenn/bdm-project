// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract CrowdfundingPlatform {
    struct Project {
        address projectCreator;
        uint goal; // ETH
        uint amountRaised; // ETH
        uint started; // timestamp
        uint deadline; // timestamp
        string projectName;
        string projectDescription;
        bool isClaimed;
    }

    mapping(uint => Project) public projects;
    mapping(uint => mapping(address => uint)) public contributions;

    uint public projectsCount;
    address public owner;

    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint id, address indexed caller, uint amount);

    constructor() payable {
        owner = payable(msg.sender);
    }

    function launch(
        string calldata _name,
        string calldata _description,
        uint _goal,
        uint _start,
        uint _end
    ) external {
        require(_goal > 0, "Goal must be greater than 0");
        require(_start >= block.timestamp, "Start time must be in the future");
        require(_end > _start, "End time must be after start time");

        projects[projectsCount] = Project({
            projectCreator: msg.sender,
            goal: _goal,
            amountRaised: 0,
            started: _start,
            deadline: _end,
            projectName: _name,
            projectDescription: _description,
            isClaimed: false
        });
        projectsCount += 1;
    }

    function pledge(uint _projectID) external payable {
        Project storage project = projects[_projectID];

        require(block.timestamp >= project.started, "Project has not started");
        require(block.timestamp <= project.deadline, "Project has ended");

        project.amountRaised += msg.value;
        contributions[_projectID][msg.sender] += msg.value;

        emit Pledge(_projectID, msg.sender, msg.value);
    }

    function claim(uint _projectID) external {
        Project storage project = projects[_projectID];

        require(
            project.amountRaised >= project.goal,
            "Project has not reached its goal"
        );
        require(
            block.timestamp > project.deadline,
            "Project has not ended yet"
        );
        require(
            project.projectCreator == msg.sender,
            "Only the project creator can claim the funds"
        );
        require(!project.isClaimed, "Funds have already been claimed");

        project.isClaimed = true;
        payable(project.projectCreator).transfer(project.amountRaised);

        emit Claim(_projectID);
    }

    function refund(uint _projectID) external payable {
        Project storage project = projects[_projectID];

        require(
            project.amountRaised < project.goal,
            "Project has reached its goal"
        );
        require(
            block.timestamp > project.deadline,
            "Project has not ended yet"
        );
        require(
            contributions[_projectID][msg.sender] > 0,
            "You have not contributed to this project"
        );

        uint amount = contributions[_projectID][msg.sender];
        contributions[_projectID][msg.sender] = 0;
        project.amountRaised -= amount;
        payable(msg.sender).transfer(amount);

        emit Refund(_projectID, msg.sender, amount);
    }
}
