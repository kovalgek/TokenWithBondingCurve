// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BancorBondingCurve} from "./BancorBondingCurve.sol";
import {CappedGasPrice} from "./CappedGasPrice.sol";

/// @author kovalgek
contract TokenWithBondingCurve is BancorBondingCurve, ERC20, CappedGasPrice {

    uint256 public scale = 10**18;
    uint256 public reserveBalance = 10*scale;
    uint256 public reserveRatio;

    error ErrorZeroReserveTokenProvided();
    error ErrorZeroContinuousTokenProvided();
    error ErrorInsufficientTokensToBurn();

    event ContinuousMint(address indexed account, uint256 amount, uint256 deposit);
    event ContinuousBurn(address indexed account, uint256 amount, uint256 reimburseAmount);

    constructor(
        uint256 _reserveRatio,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) CappedGasPrice(msg.sender) {
        reserveRatio = _reserveRatio;
        _mint(msg.sender, 1*scale);
    }

    function mint() external payable validGasPrice {
        _continuousMint(msg.value);
    }

    function burn(uint256 _amount) external validGasPrice {
        uint256 returnAmount = _continuousBurn(_amount);
        payable(msg.sender).transfer(returnAmount);
    }

    function calculateContinuousMintReturn(uint256 _amount) public view returns (uint256 mintAmount) {
        return calculatePurchaseReturn(totalSupply(), reserveBalance, uint32(reserveRatio), _amount);
    }

    function calculateContinuousBurnReturn(uint256 _amount) public view returns (uint256 burnAmount) {
        return calculateSaleReturn(totalSupply(), reserveBalance, uint32(reserveRatio), _amount);
    }

    function _continuousMint(uint256 _deposit) private returns (uint256) {
        if (_deposit == 0) {
            revert ErrorZeroReserveTokenProvided();
        }

        uint256 amount = calculateContinuousMintReturn(_deposit);
        _mint(msg.sender, amount);
        reserveBalance = reserveBalance + _deposit;
        emit ContinuousMint(msg.sender, amount, _deposit);
        return amount;
    }

    function _continuousBurn(uint256 _amount) private returns (uint256) {
        if (_amount == 0) {
            revert ErrorZeroContinuousTokenProvided();
        }
        if (balanceOf(msg.sender) < _amount) {
            revert ErrorInsufficientTokensToBurn();
        }

        uint256 reimburseAmount = calculateContinuousBurnReturn(_amount);
        reserveBalance = reserveBalance - reimburseAmount;
        _burn(msg.sender, _amount);
        emit ContinuousBurn(msg.sender, _amount, reimburseAmount);
        return reimburseAmount;
    }
}
