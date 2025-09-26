// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TokenFinance
 * @dev A comprehensive DeFi token management system with staking, lending, and yield farming capabilities
 * @author TokenFinance Team
 */
contract Project {
    // Token state variables
    string public name = "TokenFinance";
    string public symbol = "TFN";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    uint256 public stakingRewardRate = 5; // 5% annual reward rate
    
    // Mappings
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;
    mapping(address => uint256) public loanBalance;
    mapping(address => uint256) public collateralBalance;
    
    // Constants
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization required
    uint256 public constant LOAN_INTEREST_RATE = 8; // 8% annual interest rate
    uint256 private constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event LoanTaken(address indexed borrower, uint256 loanAmount, uint256 collateralAmount);
    event LoanRepaid(address indexed borrower, uint256 repaymentAmount);
    
    // Modifiers
    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }
    
    modifier hasBalance(address _user, uint256 _amount) {
        require(balanceOf[_user] >= _amount, "Insufficient balance");
        _;
    }
    
    /**
     * @dev Constructor initializes the token with initial supply
     * @param _initialSupply Initial token supply to mint
     */
    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    /**
     * @dev Core Function 1: Advanced Token Transfer with Fee Mechanism
     * Transfers tokens with optional transaction fee for platform sustainability
     * @param _to Recipient address
     * @param _value Amount to transfer
     * @param _feeEnabled Whether to apply platform fee
     * @return success Boolean indicating successful transfer
     */
    function advancedTransfer(
        address _to, 
        uint256 _value, 
        bool _feeEnabled
    ) public validAddress(_to) hasBalance(msg.sender, _value) returns (bool success) {
        uint256 transferAmount = _value;
        uint256 fee = 0;
        
        // Calculate fee if enabled (0.1% platform fee)
        if (_feeEnabled && _value > 0) {
            fee = (_value * 10) / 10000; // 0.1% fee
            transferAmount = _value - fee;
            
            // Transfer fee to contract (platform treasury)
            balanceOf[address(this)] += fee;
            emit Transfer(msg.sender, address(this), fee);
        }
        
        // Execute transfer
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += transferAmount;
        
        emit Transfer(msg.sender, _to, transferAmount);
        return true;
    }
    
    /**
     * @dev Core Function 2: Staking System with Dynamic Rewards
     * Allows users to stake tokens and earn rewards based on staking duration
     * @param _amount Amount of tokens to stake
     * @return success Boolean indicating successful staking
     */
    function stakeTokens(uint256 _amount) public hasBalance(msg.sender, _amount) returns (bool success) {
        require(_amount > 0, "Cannot stake zero tokens");
        
        // If user already has staked tokens, calculate and add pending rewards
        if (stakedBalance[msg.sender] > 0) {
            uint256 pendingReward = calculateStakingReward(msg.sender);
            if (pendingReward > 0) {
                stakedBalance[msg.sender] += pendingReward;
                totalSupply += pendingReward; // Mint new tokens as rewards
            }
        }
        
        // Transfer tokens to staking
        balanceOf[msg.sender] -= _amount;
        stakedBalance[msg.sender] += _amount;
        stakingTimestamp[msg.sender] = block.timestamp;
        
        emit Staked(msg.sender, _amount);
        return true;
    }
    
    /**
     * @dev Core Function 3: Collateralized Lending System
     * Enables users to take loans against their token collateral
     * @param _loanAmount Amount of tokens to borrow
     * @param _collateralAmount Amount of tokens to use as collateral
     * @return success Boolean indicating successful loan creation
     */
    function takeLoan(
        uint256 _loanAmount, 
        uint256 _collateralAmount
    ) public hasBalance(msg.sender, _collateralAmount) returns (bool success) {
        require(_loanAmount > 0, "Loan amount must be greater than zero");
        require(_collateralAmount > 0, "Collateral amount must be greater than zero");
        require(loanBalance[msg.sender] == 0, "Existing loan must be repaid first");
        
        // Check collateralization ratio (150% minimum)
        uint256 requiredCollateral = (_loanAmount * COLLATERAL_RATIO) / 100;
        require(_collateralAmount >= requiredCollateral, "Insufficient collateral");
        
        // Check contract has enough liquidity
        require(balanceOf[address(this)] >= _loanAmount, "Insufficient contract liquidity");
        
        // Lock collateral
        balanceOf[msg.sender] -= _collateralAmount;
        collateralBalance[msg.sender] = _collateralAmount;
        
        // Issue loan
        loanBalance[msg.sender] = _loanAmount;
        balanceOf[msg.sender] += _loanAmount;
        balanceOf[address(this)] -= _loanAmount;
        
        emit LoanTaken(msg.sender, _loanAmount, _collateralAmount);
        return true;
    }
    
    /**
     * @dev Calculate staking rewards for a user
     * @param _staker Address of the staker
     * @return reward Calculated staking reward
     */
    function calculateStakingReward(address _staker) public view returns (uint256 reward) {
        if (stakedBalance[_staker] == 0) return 0;
        
        uint256 stakingDuration = block.timestamp - stakingTimestamp[_staker];
        uint256 annualReward = (stakedBalance[_staker] * stakingRewardRate) / 100;
        reward = (annualReward * stakingDuration) / SECONDS_PER_YEAR;
        
        return reward;
    }
    
    /**
     * @dev Unstake tokens and claim rewards
     * @param _amount Amount to unstake (0 for all)
     */
    function unstakeTokens(uint256 _amount) public {
        require(stakedBalance[msg.sender] > 0, "No staked tokens");
        
        uint256 unstakeAmount = _amount == 0 ? stakedBalance[msg.sender] : _amount;
        require(unstakeAmount <= stakedBalance[msg.sender], "Insufficient staked balance");
        
        // Calculate rewards
        uint256 reward = calculateStakingReward(msg.sender);
        
        // Update balances
        stakedBalance[msg.sender] -= unstakeAmount;
        balanceOf[msg.sender] += unstakeAmount + reward;
        
        if (reward > 0) {
            totalSupply += reward; // Mint reward tokens
        }
        
        // Reset timestamp if fully unstaked
        if (stakedBalance[msg.sender] == 0) {
            stakingTimestamp[msg.sender] = 0;
        } else {
            stakingTimestamp[msg.sender] = block.timestamp;
        }
        
        emit Unstaked(msg.sender, unstakeAmount, reward);
    }
    
    /**
     * @dev Repay loan and reclaim collateral
     * @param _repaymentAmount Amount to repay
     */
    function repayLoan(uint256 _repaymentAmount) public hasBalance(msg.sender, _repaymentAmount) {
        require(loanBalance[msg.sender] > 0, "No active loan");
        
        // Calculate interest (simplified for demo)
        uint256 totalDebt = loanBalance[msg.sender]; // In production, add accumulated interest
        
        require(_repaymentAmount >= totalDebt, "Insufficient repayment amount");
        
        // Process repayment
        balanceOf[msg.sender] -= _repaymentAmount;
        balanceOf[address(this)] += _repaymentAmount;
        
        // Return collateral
        uint256 collateralToReturn = collateralBalance[msg.sender];
        balanceOf[msg.sender] += collateralToReturn;
        
        // Reset loan data
        loanBalance[msg.sender] = 0;
        collateralBalance[msg.sender] = 0;
        
        emit LoanRepaid(msg.sender, _repaymentAmount);
    }
    
    /**
     * @dev Standard ERC20 transfer function
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        return advancedTransfer(_to, _value, false);
    }
    
    /**
     * @dev Get user's total financial position
     * @param _user User address
     * @return walletBalance User's wallet token balance
     * @return stakedAmount User's staked token amount
     * @return loanAmount User's outstanding loan balance
     * @return collateralAmount User's locked collateral amount
     */
    function getUserFinancials(address _user) public view returns (
        uint256 walletBalance,
        uint256 stakedAmount,
        uint256 loanAmount,
        uint256 collateralAmount
    ) {
        return (
            balanceOf[_user],
            stakedBalance[_user],
            loanBalance[_user],
            collateralBalance[_user]
        );
    }
}
