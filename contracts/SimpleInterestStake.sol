// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleInterestStake is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Deposited(
        address indexed sender,
        uint256 indexed id,
        uint256 amount,
        uint256 balance
    );

    event Withdrawn(
        address indexed sender,
        uint256 indexed id,
        uint256 amount,
        uint256 fee,
        uint256 balance
    );

    event InterestSet(uint256 value, uint256 timestamp);
    event FeeSet(uint256 value, uint256 timestamp);

    uint256 private constant YEAR = 365 days;

    uint256 public interest = 50 * 10**15; // 5%, 0.05 ether
    uint256 public fee = 50 * 10**15; // 15%, 0.05 ether

    IERC20 public token;

    struct StakeInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 timestamp; // The time at which the user staked tokens.
        bool isDeposit; // Ture if this transactino is deposit.
    }

    // The deposit balances of users
    mapping(address => uint256) public balances;
    // The emission balances of users
    mapping(address => uint256) public emissions;
    // The date of users' last transaction
    mapping(address => uint256) public depositDates;
    // The date of users' max Id
    mapping(address => uint256) public maxIds;
    // The of users' transaction
    mapping(address => mapping(uint256 => StakeInfo)) public stakeInfos;
    // The total staked amount
    uint256 public totalStaked;

    // Variable that prevents _deposit method from being called 2 times
    bool private locked;

    constructor() {}

    function initialize(
        address _owner,
        address _tokenAddress,
        uint256 _interest,
        uint256 _fee
    ) external onlyOwner {
        require(_owner != address(0), "zero address");
        require(_tokenAddress.code.length > 0, "not a contract address");
        token = IERC20(_tokenAddress);
        setInterest(_interest);
        setFee(_fee);
        Ownable.transferOwnership(_owner);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "deposit amount should be more than 0");
        _claim(msg.sender);
        uint256 newBalance = balances[msg.sender].add(_amount);

        balances[msg.sender] = newBalance;
        totalStaked = totalStaked.add(_amount);

        _setLocked(true);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "transfer failed"
        );
        _setLocked(false);

        uint256 _id = maxIds[msg.sender]++;
        stakeInfos[msg.sender][_id].amount = _amount;
        stakeInfos[msg.sender][_id].timestamp = _now();
        stakeInfos[msg.sender][_id].isDeposit = true;
        depositDates[msg.sender] = _now();
        emit Deposited(msg.sender, _id, _amount, newBalance);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        _claim(msg.sender);
        require(
            balances[msg.sender] > 0 && balances[msg.sender] >= _amount,
            "insufficient funds"
        );

        balances[msg.sender] = balances[msg.sender].sub(_amount);
        totalStaked = totalStaked.sub(_amount);

        uint256 feeValue = 0; //_calculateFee(msg.sender, _amount);
        uint256 realAmount = _amount.sub(feeValue);

        if (balances[msg.sender] == 0) {
            depositDates[msg.sender] = 0;
        }

        require(token.transfer(msg.sender, realAmount), "transfer failed");

        uint256 _id = maxIds[msg.sender]++;
        stakeInfos[msg.sender][_id].amount = _amount;
        stakeInfos[msg.sender][_id].timestamp = _now();
        stakeInfos[msg.sender][_id].isDeposit = false;
        depositDates[msg.sender] = _now();
        emit Withdrawn(
            msg.sender,
            _id,
            _amount,
            feeValue,
            balances[msg.sender]
        );
    }

    function calculateFee(uint256 _amount) external view returns (uint256) {
        return _calculateFee(msg.sender, _amount);
    }

    function _calculateFee(address _user, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        uint256 timePassed = _now().sub(depositDates[_user]);
        if (timePassed >= YEAR) return 0;
        uint256 feeValue = _amount
            .mul(fee)
            .div(1 ether)
            .mul(YEAR.sub(timePassed))
            .div(YEAR);
        return feeValue;
    }

    function claim() external returns (uint256) {
        return _claim(msg.sender);
    }

    function _claim(address _user) internal returns (uint256) {
        if (depositDates[_user] == 0) {
            return 0;
        }
        uint256 timePassed = _now().sub(depositDates[_user]);
        uint256 currentBalance = balances[_user];
        if (currentBalance <= 0) {
            return 0;
        }
        uint256 emission = currentBalance
            .mul(interest)
            .div(1 ether)
            .mul(timePassed)
            .div(YEAR);
        //totalStaked = totalStaked.add(emission);
        //balances[_user] = balances[_user].add(emission);
        token.transfer(_user, emission);
        emissions[_user] = emissions[_user].add(emission);
        depositDates[msg.sender] = _now();
        return emission;
    }

    function setInterest(uint256 _newInterest) public onlyOwner {
        interest = _newInterest;
        emit InterestSet(interest, _now());
    }

    function setFee(uint256 _newFee) public onlyOwner {
        fee = _newFee;
        emit FeeSet(fee, _now());
    }

    function _setLocked(bool _locked) internal {
        locked = _locked;
    }

    function _now() internal view returns (uint256) {
        // Note that the timestamp can have a 900-second error:
        // https://github.com/ethereum/wiki/blob/c02254611f218f43cbb07517ca8e5d00fd6d6d75/Block-Protocol-2.0.md
        return block.timestamp; // solium-disable-line security/no-block-members
    }
}
