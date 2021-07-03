pragma solidity 0.7.3;

/** Contracts */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/** Interfaces */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/** Libraries */
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract WMaticSmartChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per block.
        uint256 lastRewardBlock; // Last block number that Rewards distribution occurs.
        uint256 accRewardPerShare; // Accumulated Rewards per share, times 1e18. See below.
    }

    // The GAJ TOKEN!
    IERC20 public syrup;

    // THE REWARD TOKEN
    IERC20 public rewardToken;

    // Reward tokens created per block.
    uint256 public rewardPerBlock;
    // Maximum amount of GAJ that can be deposited
    uint256 public maxDeposit;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 private totalAllocPoint = 0;
    // The block number when Reward mining starts.
    uint256 public startBlock;
    // The block number when Reward mining ends.
    uint256 public bonusEndBlock;

    uint256 public burnMultiplier;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

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

    function stopReward() public onlyOwner {
        bonusEndBlock = block.number;
    }

    function adjustBlockEnd() public onlyOwner {
        uint256 totalLeft = rewardToken.balanceOf(address(this));
        bonusEndBlock = block.number + totalLeft.div(rewardPerBlock);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from);
        }
    }

    // View function to see pending Reward on frontend.
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

    // Update reward variables of the given pool to be up-to-date.
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

    // Stake SYRUP tokens to SmartChef
    function deposit(uint256 _amount) public {
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

    // Withdraw SYRUP tokens from STAKING.
    function withdraw(uint256 _amount) public {
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

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        emit EmergencyWithdraw(msg.sender, user.amount);
    }
}
