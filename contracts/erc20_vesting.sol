// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

abstract contract IERC20 {
    function transfer(address _to, uint256 _value) external virtual returns (bool success);
}

contract TokenVesting {
    uint256 public releasePeriod = 584000;  // every three months
    uint256 public releasePercentage = 500;  // e.g. 3.5% ==> 350

    address public tokenContract;
    uint256 public releaseBlockNumber;  // after which block number first vesting amount should be released

    mapping(address => uint256) public ownerToOriginalAmount;
    mapping(address => uint256) public ownerAlreadyWithdrew;
    mapping(address => bool) public ownerBlocked;

    bool public paused = false;
    address public owner;
    address public newContractOwner;

    event Pause();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor (address _tokenContract, uint256 _firstReleaseBlockNumber) {
        tokenContract = _tokenContract;
        releaseBlockNumber = _firstReleaseBlockNumber;
        owner = msg.sender;
    }

    modifier ifNotPaused {
        require(!paused);
        _;
    }

    modifier onlyContractOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) external onlyContractOwner {
        require(_newOwner != address(0));
        newContractOwner = _newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == newContractOwner);
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

    function setInvestor(address wallet, uint256 amount) external onlyContractOwner {
        ownerToOriginalAmount[wallet] = amount;
        ownerAlreadyWithdrew[wallet] = 0;
    }

    function setReleaseParameters(uint256 _releasePeriod, uint256 _releasePercentage) external onlyContractOwner {
        releasePeriod = _releasePeriod;
        releasePercentage = _releasePercentage;
    }

    function setAddressBlock(address wallet, bool isBlocked) external onlyContractOwner {
        ownerBlocked[wallet] = isBlocked;
    }

    function claim() external ifNotPaused {
        require(block.number >= releaseBlockNumber, "Release block number has not been reached yet.");
        require(!ownerBlocked[msg.sender]);
        IERC20 token = IERC20(tokenContract);

        uint256 multiplier = (block.number - releaseBlockNumber) / releasePeriod;
        uint256 unitAmount = ownerToOriginalAmount[msg.sender] * releasePercentage / 10000;
        uint256 amount = (multiplier * unitAmount) - ownerAlreadyWithdrew[msg.sender];
        if (amount + ownerAlreadyWithdrew[msg.sender] > ownerToOriginalAmount[msg.sender]) {
            amount = ownerToOriginalAmount[msg.sender] - ownerAlreadyWithdrew[msg.sender];
        }

        require(ownerToOriginalAmount[msg.sender] > ownerAlreadyWithdrew[msg.sender], "You have already withdrawn the whole amount.");
        require(amount > 0, "You are not eligible for a withdrawal at the moment.");
        ownerAlreadyWithdrew[msg.sender] += amount;
        token.transfer(msg.sender, amount);
    }

    receive() external payable {

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