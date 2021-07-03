pragma solidity 0.7.3;

/** Contracts */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/** Interfaces */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/** Libraries */
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract SmartChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /*************
     * Variables *
     *************/

    /** @dev A struct storing user information */
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    /** @dev A struct storing pool information */
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per block.
        uint256 lastRewardBlock; // Last block number that Rewards distribution occurs.
        uint256 accRewardPerShare; // Accumulated Rewards per share, times 1e18. See below.
    }

    /** @dev GAJ token contract */
    IERC20 public syrup;

    /** @dev The token that is rewarded to users */
    IERC20 public rewardToken;

    /** @dev A number indicating the rewards per block */
    uint256 public rewardPerBlock;

    /** @dev A maximum deposit limit  */
    uint256 public maxDeposit;

    /** @dev An array of pool data */
    PoolInfo[] public poolInfo;

    /** @dev An array of user data */
    mapping(address => UserInfo) public userInfo;

    /** @dev Sum of all allocation points in all pools */
    uint256 private totalAllocPoint;

    /** @dev Block number representing the start of reward mining  */
    uint256 public startBlock;

    /** @dev Block number representing the end of reward mining */
    uint256 public bonusEndBlock;

    /** @dev Burn multiplier, scaled by 1e3 */
    uint256 public burnMultiplier;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    /***************
     * Constructor *
     ***************/
    constructor(
        IERC20 _syrup,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _burnMultiplier,
        uint256 _maxDeposit
    ) public {
        syrup = _syrup;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        burnMultiplier = _burnMultiplier;
        maxDeposit = _maxDeposit;

        // staking pool
        poolInfo.push(PoolInfo({lpToken: _syrup, allocPoint: 1000, lastRewardBlock: startBlock, accRewardPerShare: 0}));

        totalAllocPoint = 1000;
    }

    /********************
     * External Functions *
     *********************/

    /** @dev Deposit stake tokens into the contract */
    function deposit(uint256 _amount) external {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        require(pool.lpToken.balanceOf(address(this)) <= maxDeposit, "Deposit limit reached!!");
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e18);
                rewardToken.safeTransfer(address(msg.sender), pending);
            }
        }
        if (_amount > 0) {
            uint256 burnAmount = _amount.mul(burnMultiplier).div(1000);
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount - burnAmount);
            if (burnAmount > 0) {
                pool.lpToken.safeTransferFrom(address(msg.sender), address(0x00dead), burnAmount);
            }
            user.amount = user.amount.add(_amount - burnAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e18);

        emit Deposit(msg.sender, _amount);
    }

    /** @dev Withdraw tokens from the contract */
    function withdraw(uint256 _amount) external {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            rewardToken.safeTransfer(address(msg.sender), pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e18);

        emit Withdraw(msg.sender, _amount);
    }

    /** 
        @dev Withdraw, ignoring rewards. 
        @notice EMERGENCY ONLY 
    */
    function emergencyWithdraw() external {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    /** @dev Stop rewards  */
    function stopReward() external onlyOwner {
        bonusEndBlock = block.number;
    }

    /** @dev Update the end block  */
    function adjustBlockEnd() external onlyOwner {
        uint256 totalLeft = rewardToken.balanceOf(address(this));
        bonusEndBlock = block.number + totalLeft.div(rewardPerBlock);
    }

    /** @return The pending reward for a given user */
    function pendingReward(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 cakeReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardPerShare = accRewardPerShare.add(cakeReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e18).sub(user.rewardDebt);
    }

    /********************
     * Public Functions *
     ********************/

    /** @return reward multiplier over the given block period */
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from);
        }
    }

    /** @dev Update pool variables for a given pool */
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 cakeReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accRewardPerShare = pool.accRewardPerShare.add(cakeReward.mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }
}
