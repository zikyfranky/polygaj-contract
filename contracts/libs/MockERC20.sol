pragma solidity 0.7.3;
/* Contracts */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    constructor(
        string memory _name, 
        string memory _symbol, 
        uint256 _supply
    ) ERC20(_name, _symbol){
        _mint(msg.sender, _supply);
    } 
}