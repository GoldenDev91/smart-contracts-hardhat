// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WorldCupBet is Context, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Bet(
        uint256 indexed matchIndex,
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );

    event Claim(
        uint256 indexed matchIndex,
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );

    IERC20 public token;

    struct MatchInfo {
        string team1;
        string team2;
        uint256 time;
        string level;
        mapping(address => uint256) choices; // 1: team1, 2: team2, 3: draw
        uint256[4] choiceCounters; // 1: team1, 2: team2, 3: draw
        mapping(address => uint256) betAmounts;
        mapping(address => uint256) awardAmounts;
        uint256 result;
        uint256 betAmount;
        uint256 awardAmount;
        // 50 * 10 ** 15; // 5%, 0.05 ether
        uint256 team1AwardRate;
        uint256 team2AwardRate;
        uint256 drawAwardRate;
    }

    uint256 public totalBetAmount = 0;
    uint256 public totalAwardAmount = 0;

    MatchInfo[] public matchInfos;

    bool private locked;

    constructor() {}

    function initialize(address _owner, address _tokenAddress)
        external
        onlyOwner
    {
        require(_owner != address(0), "zero address");
        require(_tokenAddress.code.length > 0, "not a contract address");
        token = IERC20(_tokenAddress);
        Ownable.transferOwnership(_owner);
    }

    function getChoiceCounts(uint256 _matchIndex)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        require(address(token) != address(0), "not initialized");

        return (
            matchInfos[_matchIndex].choiceCounters[0],
            matchInfos[_matchIndex].choiceCounters[1],
            matchInfos[_matchIndex].choiceCounters[2],
            matchInfos[_matchIndex].choiceCounters[3]
        );
    }

    function getChoice(uint256 _matchIndex, address _beter)
        public
        view
        returns (uint256)
    {
        require(address(token) != address(0), "not initialized");

        return matchInfos[_matchIndex].choices[_beter];
    }

    function getBetAmount(uint256 _matchIndex, address _beter)
        public
        view
        returns (uint256)
    {
        require(address(token) != address(0), "not initialized");

        return matchInfos[_matchIndex].betAmounts[_beter];
    }

    function getAwardAmount(uint256 _matchIndex, address _beter)
        public
        view
        returns (uint256)
    {
        require(address(token) != address(0), "not initialized");

        return matchInfos[_matchIndex].awardAmounts[_beter];
    }

    function addMatch(
        string memory _team1,
        string memory _team2,
        uint256 _time,
        string memory _level,
        uint256 _team1AwardRate,
        uint256 _team2AwardRate,
        uint256 _drawAwardRate
    ) external onlyOwner returns (uint256) {
        require(address(token) != address(0), "not initialized");

        uint256 lastIndex = matchInfos.length;
        matchInfos.push();

        MatchInfo storage newMatch = matchInfos[lastIndex];

        newMatch.team1 = _team1;
        newMatch.team2 = _team2;
        newMatch.time = _time;
        newMatch.level = _level;
        newMatch.team1AwardRate = _team1AwardRate;
        newMatch.team2AwardRate = _team2AwardRate;
        newMatch.drawAwardRate = _drawAwardRate;

        return matchInfos.length;
    }

    function updateMatch(
        uint256 _index,
        string memory _team1,
        string memory _team2,
        string memory _level,
        uint256 _time,
        uint256 _team1AwardRate,
        uint256 _team2AwardRate,
        uint256 _drawAwardRate
    ) external onlyOwner {
        require(address(token) != address(0), "not initialized");

        matchInfos[_index].team1 = _team1;
        matchInfos[_index].team2 = _team2;
        matchInfos[_index].time = _time;
        matchInfos[_index].level = _level;
        matchInfos[_index].team1AwardRate = _team1AwardRate;
        matchInfos[_index].team2AwardRate = _team2AwardRate;
        matchInfos[_index].drawAwardRate = _drawAwardRate;
    }

    function setMatchResult(uint256 _index, uint256 _result)
        external
        onlyOwner
    {
        require(address(token) != address(0), "not initialized");
        require(
            matchInfos[_index].time + 100 * 60 < block.timestamp,
            "too early to set result"
        );

        require(_result > 0 && _result < 4, "Wrong result");
        matchInfos[_index].result = _result;
    }

    function matchCount() public view returns (uint256) {
        return matchInfos.length;
    }

    function bet(
        uint256 _matchIndex,
        uint256 _choice,
        uint256 _amount
    ) external {
        require(address(token) != address(0), "not initialized");

        require(_amount > 0, "amount should be more than 0");
        require(
            matchInfos[_matchIndex].betAmounts[msg.sender] == 0,
            "already bet"
        );
        require(
            matchInfos[_matchIndex].time > block.timestamp,
            "too late to bid"
        );
        require(_choice > 0 && _choice < 4, "wrong choice");

        matchInfos[_matchIndex].betAmounts[msg.sender] = _amount;
        matchInfos[_matchIndex].choices[msg.sender] = _choice;
        matchInfos[_matchIndex].choiceCounters[_choice] = matchInfos[
            _matchIndex
        ].choiceCounters[_choice].add(1);
        matchInfos[_matchIndex].betAmount = matchInfos[_matchIndex]
            .betAmount
            .add(_amount);
        totalBetAmount = totalBetAmount.add(_amount);

        _setLocked(true);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "transfer failed"
        );
        _setLocked(false);

        emit Bet(_matchIndex, msg.sender, _amount, _now());
    }

    function claim(uint256 _matchIndex)
        external
        nonReentrant
        returns (uint256)
    {
        require(address(token) != address(0), "not initialized");

        require(
            matchInfos[_matchIndex].result > 0,
            "Result not set, try later"
        );
        require(matchInfos[_matchIndex].betAmounts[msg.sender] > 0, "No bet");
        require(
            matchInfos[_matchIndex].choices[msg.sender] ==
                matchInfos[_matchIndex].result,
            "Wrong bet"
        );

        uint256 amount = matchInfos[_matchIndex].betAmounts[msg.sender];
        uint256 awardRate = 0;
        if (matchInfos[_matchIndex].result == 1) {
            awardRate = matchInfos[_matchIndex].team1AwardRate;
        }
        if (matchInfos[_matchIndex].result == 2) {
            awardRate = matchInfos[_matchIndex].team2AwardRate;
        }
        if (matchInfos[_matchIndex].result == 3) {
            awardRate = matchInfos[_matchIndex].drawAwardRate;
        }
        uint256 award = amount.mul(awardRate).div(1 ether);

        matchInfos[_matchIndex].awardAmounts[msg.sender] = award;
        matchInfos[_matchIndex].awardAmount = matchInfos[_matchIndex]
            .awardAmount
            .add(award);
        totalAwardAmount = totalAwardAmount.add(award);

        _setLocked(true);
        require(token.transfer(msg.sender, award), "transfer failed");
        _setLocked(false);

        emit Claim(_matchIndex, msg.sender, amount, _now());

        return award;
    }

    function _setLocked(bool _locked) internal {
        locked = _locked;
    }

    function _now() internal view returns (uint256) {
        // Note that the timestamp can have a 900-second error:
        // https://github.com/ethereum/wiki/blob/c02254611f218f43cbb07517ca8e5d00fd6d6d75/Block-Protocol-2.0.md
        return block.timestamp; // solium-disable-line security/no-block-members
    }

    function recoverTokens(uint256 tokenAmount)
        public
        virtual
        onlyOwner
    {
        token.transfer(owner(), tokenAmount);
    }
}
//0x63274c9d186154245bC92ca203ec65F3C1724d5F