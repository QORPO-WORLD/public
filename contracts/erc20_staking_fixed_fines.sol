// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

abstract contract IERC20 {
    function transfer(address _to, uint256 _value) external virtual returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external virtual returns (bool success);
}

contract TokenStaking {

    address public tokenContract;
    mapping(uint256 => uint256) public durationToInterest;  // e.g. 3.5% ==> 1035
    mapping(uint256 => uint256) public durationToFine;  // e.g. 9% ==> 910 (1000 minus fine)

    mapping(address => uint256) public ownerToStakedValue;
    mapping(address => uint256) public ownerToReleaseTime;
    mapping(address => uint256) public ownerToReleaseValue;
    mapping(address => uint256) public ownerToFinedValue;

    bool public paused = false;
    address public owner;
    address public newContractOwner;

    event Pause();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        owner = msg.sender;
    }

    modifier ifNotPaused {
        require(!paused, "Contract is paused.");
        _;
    }

    modifier onlyContractOwner {
        require(msg.sender == owner, "Not authorized.");
        _;
    }

    function transferOwnership(address _newOwner) external onlyContractOwner {
        require(_newOwner != address(0), "Invalid address.");
        newContractOwner = _newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == newContractOwner, "Not authorized to accept ownership.");
        emit OwnershipTransferred(owner, newContractOwner);
        owner = newContractOwner;
        newContractOwner = address(0);
    }

    function setPause(bool _paused) external onlyContractOwner {
        paused = _paused;
        if (paused) {
            emit Pause();
        }
    }

    function setInterestAndFine(uint256 _duration, uint256 _interest, uint256 _fine) external onlyContractOwner {
        durationToInterest[_duration] = _interest;
        durationToFine[_duration] = _fine;
    }

    function setTokenContract(address _tokenContract) external onlyContractOwner {
        tokenContract = _tokenContract;
    }

    function stake(uint256 _value, uint256 _duration) external payable ifNotPaused {
        require(ownerToStakedValue[msg.sender] == 0, "This address is already staking!");
        IERC20 token = IERC20(tokenContract);
        token.transferFrom(msg.sender, address(this), _value);

        ownerToStakedValue[msg.sender] = _value;
        ownerToReleaseTime[msg.sender] = block.timestamp + (_duration * 2628000);  // one month equals 2628000 secs
        ownerToReleaseValue[msg.sender] = (_value * durationToInterest[_duration]) / 1000;
        ownerToFinedValue[msg.sender] = (_value * durationToFine[_duration]) / 1000;
    }

    function claim() external payable ifNotPaused {
        require(block.timestamp >= ownerToReleaseTime[msg.sender], "Your staking has not ended yet.");
        require(ownerToReleaseValue[msg.sender] > 0, "Release value is zero.");

        delete ownerToReleaseTime[msg.sender];
        delete ownerToFinedValue[msg.sender];
        delete ownerToStakedValue[msg.sender];
        delete ownerToReleaseValue[msg.sender];

        IERC20 token = IERC20(tokenContract);
        token.transfer(msg.sender, ownerToReleaseValue[msg.sender]);
    }

    function cancel() external payable ifNotPaused {
        delete ownerToReleaseTime[msg.sender];
        delete ownerToFinedValue[msg.sender];
        delete ownerToStakedValue[msg.sender];
        delete ownerToReleaseValue[msg.sender];

        IERC20 token = IERC20(tokenContract);
        if (block.timestamp >= ownerToReleaseTime[msg.sender]) {
            require(ownerToReleaseValue[msg.sender] > 0, "Release value is zero.");
            token.transfer(msg.sender, ownerToReleaseValue[msg.sender]);
        } else {
            require(ownerToFinedValue[msg.sender] > 0, "Fined value is zero");
            token.transfer(msg.sender, ownerToFinedValue[msg.sender]);
        }
    }

    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }

    function withdrawBalance(uint256 _amount) external onlyContractOwner {
        payable(owner).transfer(_amount);
    }

    function withdrawTokenBalance(address _address, uint256 _amount) external onlyContractOwner {
        IERC20 token = IERC20(_address);
        token.transfer(msg.sender, _amount);
    }

}