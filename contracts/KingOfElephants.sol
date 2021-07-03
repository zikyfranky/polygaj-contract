pragma solidity 0.7.3;

/* Contracts */
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/* Libraries */
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/* Interfaces */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KingOfElephants is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    IERC20 public token;

    uint256 public lastBidTime;
    address public lastBidder;

    address public burnAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public amountBurned = 0;

    event OnBid(address indexed author, uint256 amount);
    event OnWin(address indexed author, uint256 amount);
    event OnBurn(uint256 amount);

    uint32 public endDelay = 600; // default 10 mins
    uint256 public coolDownTime = 43200; // default 24 Hours
    uint256 public nextStartTime = 0;
    uint256 public bidAmount = 2000000000000000000; //default 1.0 GAJ

    modifier notContract() {
        require(!address(msg.sender).isContract(), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    constructor(address _token) public {
        token = IERC20(_token);
    }

    // 27-apr-21: amount is set by the smart contract, slippage is not used anymore
    function participate(uint256 amount) public nonReentrant notContract() {
        require(!hasWinner(), "winner, claim first");
        require(block.timestamp >= nextStartTime, "CoolDown period not met");
        uint256 currentBalance = token.balanceOf(address(this));
        require(amount == bidAmount, "amount must be equal to bidAmount");

        uint256 burnAmount = amount / 10; // 10%
        amountBurned += burnAmount;
        token.safeTransferFrom(msg.sender, burnAddress, burnAmount);
        token.safeTransferFrom(msg.sender, address(this), amount - burnAmount);

        emit OnBid(msg.sender, amount);
        emit OnBurn(burnAmount);

        lastBidTime = block.timestamp;
        lastBidder = msg.sender;
    }

    function hasWinner() public view returns (bool) {
        return lastBidTime != 0 && block.timestamp - lastBidTime >= endDelay;
    }

    function claimReward() public nonReentrant notContract() {
        require(hasWinner(), "no winner yet");

        uint256 totalBalance = token.balanceOf(address(this));
        uint256 winAmount = (totalBalance / 100) * 50; //50%
        uint256 nextRoundAmount = (totalBalance / 100) * 20; //20%
        uint256 burnAmount = totalBalance - winAmount - nextRoundAmount; //30%
        amountBurned += burnAmount;
        token.safeTransfer(lastBidder, winAmount);
        token.safeTransfer(burnAddress, burnAmount);
        lastBidTime = 0;
        nextStartTime = block.timestamp + coolDownTime;
        emit OnWin(lastBidder, winAmount);
        emit OnBurn(burnAmount);
    }

    function setEndDelay(uint32 delay) public onlyOwner {
        require(delay >= 60, "must be at least a minute");
        endDelay = delay;
    }

    function setCoolDownTime(uint256 time) public onlyOwner {
        require(time >= 0, "Should be valid");
        coolDownTime = time;
    }

    function setBidAmount(uint256 _bidAmount) public onlyOwner {
        require(_bidAmount > 0, "must be positive");
        bidAmount = _bidAmount;
    }

    function safeTransferToV2(uint256 amount) external nonReentrant onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }
}
