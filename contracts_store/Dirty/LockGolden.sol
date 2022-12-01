// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (lock/LockGolden.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IERC20Metadata.sol";
import "./Context.sol";

contract LockGolden {
    struct staker {
        uint256 amount;
        uint256 pendingReward;
        uint256 lockedTime;
        uint256 expireTime;
    }

    event Withdraw(address account, uint256 amount);
    event Stake(address account, uint256 amount, uint256 unlocktime);

    IERC20 public golden = IERC20(0x1301753A606EC4E722AA754957Dc309332EcD275);
    //this: 0x87D91B46BF83F84252126A7849419d3C58c3AFb8
    mapping(address => staker) public _stakers;

    function stake(
        address account,
        uint256 amount,
        uint8 unlockTime
    ) public returns (uint256 currentBalance, staker memory currentStaker) {
        require(amount != 0, "amount must not 0");
        require(
            unlockTime == 10 || unlockTime == 20 || unlockTime == 30,
            "unlockTime must be 10, 20 or 30."
        );

        if (unlockTime == 10)
            require(amount >= 500, "Too little money, bet more!");
        if (unlockTime == 20)
            require(amount >= 1000, "Too little money, bet more!");
        if (unlockTime == 30)
            require(amount >= 3000, "Too little money, bet more!");
        staker storage _staker = _stakers[account];
        require(
            _staker.amount == 0,
            "You have already bet. Wait until current bet expires."
        );
        _staker.amount = amount;
        _staker.pendingReward = amount * 2;
        _staker.lockedTime = block.timestamp;
        _staker.expireTime = block.timestamp + unlockTime;

        if (golden.transferFrom(msg.sender, address(this), amount)) {
            emit Stake(account, amount, block.timestamp + unlockTime);
            return (golden.balanceOf(account), _staker);
        }
    }

    function withdraw(address account) public returns (uint256 currentBalance) {
        staker memory currentStaker = _stakers[account];
        require(currentStaker.amount != 0, "You didn't bet yet.");
        require(
            block.timestamp > currentStaker.expireTime,
            "Please wait until bet expires."
        );

        if (
            golden.transfer(account, currentStaker.pendingReward)
        ) {
            _stakers[account].amount = 0;
            emit Withdraw(account, currentStaker.amount);
            return golden.balanceOf(account);
        }
    }
}
