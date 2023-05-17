// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Fundraising is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    // a round of fundraising activity 
    struct Round {
        address targetToken; // address(0) represent FIL
        uint targetAmount; 
        uint interestRate; 
        uint startAt; 
        uint duration; 
        uint lockPerioad; 
        uint currentAmount; 
        bool isTaken;
    }

    struct UserInfo {
        uint amount; // lock amount
        uint lastClaimAt; // last claim rewards timestamp
        bool isWithdrawn; // if withdraw the locked token
    }

    uint constant public BASE_POINT = 10000;
    address public creator;
    address public taker;
    uint public currentRoundId; 
    mapping (uint => Round) public round; 
    mapping (address => mapping (uint => UserInfo)) public userInfo; // address => roundId => UserInfo

    event NewRound(uint roundId, address targetToken, uint targetAmount, uint startAt, uint duration, uint lockPeriod);
    event Collect(address user, uint roundId, uint amount);
    event TakeTokens(address taker, uint roundId, address targetToken, uint amount);
    event Claim(address user, uint roundId, uint amount);
    event Withdraw(address user, uint roundId, uint amount);
    event SetTaker(address oldTaker, address newTaker);
    event SetCreator(address oldCreator, address newCreator);

    modifier validateRound(uint roundId) {
        require(roundId > 0 && roundId <= currentRoundId, "round not exist");
        _;
    }

     function initialize(address _creator, address _taker) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        _setCreator(_creator);
        _setTaker(_taker);
    }

    function setCreator(address newCreator) external onlyOwner {
        _setCreator(newCreator);
    }

    function _setCreator(address _creator) private {
        emit SetCreator(creator, _creator);
        creator = _creator;
    }

    function setTaker(address newTaker) external onlyOwner {
        _setTaker(newTaker);
    }

    function _setTaker(address _taker) private {
        emit SetTaker(taker, _taker);
        taker = _taker;
    }

    function pendingReward(address account, uint roundId) public view returns (uint) {
        UserInfo storage user = userInfo[account][roundId];
        Round storage r = round[roundId];
        uint endTimestamp = r.startAt + r.duration + r.lockPerioad;
        if (user.amount == 0 || user.lastClaimAt >= endTimestamp || block.timestamp <= user.lastClaimAt) {
            return 0;
        }
        // totalReward = user.amount * interestRate / BASE_POINT;
        // pendingReward = totalReward / lockperiod * (block.timestamp - lastClaimAt);
        uint currentTimestamp = block.timestamp >= endTimestamp ? endTimestamp : block.timestamp;
        return user.amount * r.interestRate * (currentTimestamp - user.lastClaimAt) / (BASE_POINT * r.lockPerioad);
    }

    // create a new round
    function createRound(address _targetToken, uint _targetAmount, uint _interestRate, uint _startAt, uint _duration, uint _lockPeriod) external {
        require(address(msg.sender) == creator, "only creator can call");
        require(_startAt >= block.timestamp, "start time less than now");
        require(_targetAmount != 0 && _duration != 0, "incorrect params: targetAmount or duration is zero");
        currentRoundId++;
        Round storage newRound = round[currentRoundId];
        newRound.targetToken = _targetToken;
        newRound.targetAmount = _targetAmount;
        newRound.interestRate = _interestRate;
        newRound.currentAmount = 0;
        newRound.startAt = _startAt;
        newRound.duration = _duration;
        newRound.lockPerioad = _lockPeriod;
        newRound.isTaken = false;
        emit NewRound(currentRoundId, _targetToken, _targetAmount, _startAt, _duration, _lockPeriod);
    }

    // collect fund
    function collect(uint roundId, uint amount) external payable validateRound(roundId) {
        Round storage r = round[roundId];
        require(block.timestamp >= r.startAt, "collect: this round hasn't started yet");
        require(block.timestamp <= r.startAt + r.duration, "collect: this round has ended");
        require(r.currentAmount + amount <= r.targetAmount, "collect: collected amount exceed target amount");
        if (r.targetToken == address(0)) {
            require(amount == msg.value, "collect: invalid transfer amount");
        } else {
            IERC20 targetToken = IERC20(r.targetToken);
            require(targetToken.balanceOf(address(msg.sender)) >= amount, "collect: balance not enough");
            require(targetToken.allowance(address(msg.sender), address(this)) >= amount, "collect: not approve");
            targetToken.safeTransferFrom(address(msg.sender), address(this), amount);
            r.currentAmount += amount;
        }
       
        UserInfo storage user = userInfo[msg.sender][roundId];
        user.amount += amount;
        if (user.lastClaimAt == 0) {
            user.lastClaimAt = r.startAt + r.duration;
        }
        emit Collect(address(msg.sender), roundId, amount);
    }

     
    function takeTokens(uint roundId) external validateRound(roundId) {
        require(address(msg.sender) == taker, "only taker can call");
        Round storage r = round[roundId];
        require(block.timestamp >= r.startAt + r.duration, "this round hasn't ended yet");
        require(!r.isTaken, "tokens that this round collected has been taken");
        r.isTaken = true;
        if (r.targetToken == address(0)) {
            require(address(this).balance >= r.currentAmount, "target token balance not enough");
            safeTransferFIL(address(msg.sender), r.currentAmount);
        } else {
            IERC20 targetToken = IERC20(r.targetToken);
            require(targetToken.balanceOf(address(this)) >= r.currentAmount, "target token balance not enough");
            targetToken.safeTransfer(address(msg.sender), r.currentAmount);
        }
        emit TakeTokens(address(msg.sender), roundId, r.targetToken, r.currentAmount);
    }

    function claim(uint roundId) external validateRound(roundId) {
        uint reward = pendingReward(msg.sender, roundId);
        if (reward == 0) {
            return;
        }
        Round storage r = round[roundId];
        UserInfo storage user = userInfo[msg.sender][roundId];
        user.lastClaimAt = block.timestamp;
        if (r.targetToken == address(0)) {
            require(address(this).balance >= reward, "claim: balance not enough");
            safeTransferFIL(address(msg.sender), reward);
        } else {
            require(IERC20(r.targetToken).balanceOf(address(this)) >= reward, "claim: balance not enough");
            IERC20(r.targetToken).safeTransfer(address(msg.sender), reward);
        }
        emit Claim(msg.sender, roundId, reward);
    }

    function withdraw(uint roundId) external validateRound(roundId) {
        Round storage r = round[roundId];
        UserInfo storage user = userInfo[msg.sender][roundId];
        require(!user.isWithdrawn, "already withdraw");
        require(block.timestamp > r.startAt + r.duration + r.lockPerioad, "withdraw: it is not time to unlock");
        user.isWithdrawn = true;
        if (r.targetToken == address(0)) {
            require(address(this).balance >= user.amount, "withdraw: balance not enough");
            safeTransferFIL(address(msg.sender), user.amount);
        } else {
            require(IERC20(r.targetToken).balanceOf(address(this)) >= user.amount, "withdraw: balance not enough");
            IERC20(r.targetToken).safeTransfer(address(msg.sender), user.amount);
        }
        emit Withdraw(msg.sender, roundId, user.amount);
    }

    function safeTransferFIL(address to, uint value) internal {
        (bool success,) = to.call{value: value}("");
        require(success, "transfer FIL failed");
    }
}