// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin ERC20 ve Ownable sözleşmelerini içeri aktar
import "./IMccb.sol";

// ERC20 token kontratını tanımla
contract MccbToken is IMccb {
    // Foundation wallet address (30% of tokens)
    address public immutable foundation_Wallet;
    address private _owner; // Address of the contract owner
    address private _bridge; // Address of the contract bridge

    mapping(address => Account) private accounts;

    // structure and mappings for admin status, balances, allowances, blacklisting, and frozen accounts
    struct Account {
        uint256 _balances;
        mapping(address => uint256) _allowances;
    }

    // Struct to store initial distribution details
    struct Distribution {
        address account;
        uint256 amount;
    }
    Distribution[] private distributions;

    bool entered;

    // Modifier to prevent reentrant calls to a function
    modifier reentrancy() {
        if (entered) {
            revert ReentrancyGuardReentrantCall();
        }
        entered = true;
        _;
        entered = false;
    }

    // Modifier to restrict access to only the owner
    modifier onlyOwner() {
        require(
            (_owner == msg.sender || _bridge == msg.sender),
            "Ownable:caller isn't the owner"
        );
        _;
    }

    // Token details
    uint8 private constant DECIMALS = 18;
    string private constant NAME = "IMccb Token";
    string private constant SYMBOL = "IMCCB";
    uint256 private _totalSupply = (120 * 10 ** 7) * (10 ** DECIMALS);

    // Token distribution shares
    uint256 private constant FOUNDATION_SHARE =
        (120 * 10 ** 7) * (10 ** DECIMALS); // for foundation

    // Event emitted on Burn
    event Burn(address indexed account, uint256 value);

    // Event for ownership transfer
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // Custom error for reentrancy guard violation
    error ReentrancyGuardReentrantCall();

    // Custom error for transfer amounts exceeding the sender's balance
    error TransferAmountExceedsBalance(
        address sender,
        uint256 amount,
        uint256 balance
    );

    // Custom error for transfer amounts exceeding the allowed amount
    error TransferAmountExceedsAllowance(
        address sender,
        address spender,
        uint256 amount,
        uint256 allowance
    );

    // Custom error for invalid address
    error InvalidAddress(address addr);

    // Custom error for invalid amount
    error InvalidAmount(uint256 amount);

    // Custom error for transfer amount exceeding the max allowed amount
    error TransferAmountExceedsMaxAmount(uint256 amount, uint256 maxAmount);

    // Constructor to initialize the contract with token metadata URL and mint initial supply
    constructor( ) {
        _owner = msg.sender;
        foundation_Wallet = payable(msg.sender);

        // Distribute tokens to the specified addresses
        _distributeTokens(foundation_Wallet, FOUNDATION_SHARE);
    }

    // Internal function to distribute tokens and store distribution details
    function _distributeTokens(address account, uint256 amount) internal {
        if (account == address(0)) revert InvalidAddress(account);
        accounts[account]._balances = amount;
        emit Transfer(address(0), account, amount);
        distributions.push(Distribution(account, amount));
    }

    // ERC20 standard functions

    // Function to get the token name
    function name() public pure returns (string memory) {
        return NAME;
    }

    // Function to get the token symbol
    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    // Function to get the token decimals
    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    // Function to get the total token supply
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    // Function to get the token balance of an account
    function balanceOf(address account) public view override returns (uint256) {
        return accounts[account]._balances;
    }

    // Function to transfer tokens from the sender to another account
    function transfer(
        address receiver,
        uint256 amount
    ) public override reentrancy returns (bool) {
        if (receiver == address(0)) revert InvalidAddress(receiver);
        if (amount == 0) revert InvalidAmount(amount);
        if (accounts[msg.sender]._balances < amount)
            revert TransferAmountExceedsBalance(
                msg.sender,
                amount,
                accounts[msg.sender]._balances
            );

        accounts[msg.sender]._balances -= amount;
        accounts[receiver]._balances += amount;
        emit Transfer(msg.sender, receiver, amount);
        return true;
    }

    // Function to transfer tokens on behalf of an owner
    function transferFrom(
        address onbehalfof,
        address receiver,
        uint256 amount
    ) public override reentrancy returns (bool) {
        if (onbehalfof == address(0)) revert InvalidAddress(onbehalfof);
        if (receiver == address(0)) revert InvalidAddress(receiver);
        if (amount == 0) revert InvalidAmount(amount);
        if (accounts[onbehalfof]._balances < amount)
            revert TransferAmountExceedsBalance(
                onbehalfof,
                amount,
                accounts[onbehalfof]._balances
            );
        if (accounts[onbehalfof]._allowances[msg.sender] < amount)
            revert TransferAmountExceedsAllowance(
                onbehalfof,
                msg.sender,
                amount,
                accounts[onbehalfof]._allowances[msg.sender]
            );

        accounts[onbehalfof]._balances -= amount;
        accounts[onbehalfof]._allowances[msg.sender] -= amount;
        accounts[receiver]._balances += amount;
        emit Transfer(onbehalfof, receiver, amount);
        return true;
    }

    // Function to check the allowance of a spender
    function allowance(
        address onbehalfof,
        address spender
    ) public view override returns (uint256) {
        return accounts[onbehalfof]._allowances[spender];
    }

    // Function to increase the allowance of a spender
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual reentrancy returns (bool) {
        accounts[msg.sender]._allowances[spender] += addedValue;
        _approve(
            msg.sender,
            spender,
            accounts[msg.sender]._allowances[spender]
        );
        return true;
    }

    // Function to decrease the allowance of a spender
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual reentrancy returns (bool) {
        require(
            accounts[msg.sender]._allowances[spender] >=
                subtractedValue,
            "decreased allowance below 0"
        );

        accounts[msg.sender]._allowances[spender] -= subtractedValue;
        _approve(
            msg.sender,
            spender,
            accounts[msg.sender]._allowances[spender]
        );
        return true;
    }

    // Function to approve a spender
    function approve(
        address spender,
        uint256 amount
    ) public override reentrancy returns (bool) {
        require(
            (amount == 0) ||
                (accounts[msg.sender]._allowances[spender] == 0),
            "Non-zero approval.first->zero"
        );
        _approve(msg.sender, spender, amount);
        return true;
    }

    // Internal function to set the allowance of a spender
    function _approve(
        address onbehalfof,
        address spender,
        uint256 amount
    ) private {
        if (onbehalfof == address(0)) revert InvalidAddress(onbehalfof);
        if (spender == address(0)) revert InvalidAddress(spender);

        accounts[onbehalfof]._allowances[spender] = amount;
        emit Approval(onbehalfof, spender, amount);
    }

    // Function to mint new tokens
    function mint(address account, uint256 amount) external virtual onlyOwner reentrancy {
        _mint(account, amount);
    }

    // Internal function to mint tokens from an account
    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert InvalidAddress(account);
        if (amount == 0) revert InvalidAmount(amount);

        _totalSupply += amount;
        accounts[account]._balances += amount;

        emit Transfer(address(0), account, amount);
    }


    // Function to burn tokens from an account
    function burn(uint256 value) external virtual onlyOwner reentrancy {
        _burn(value);
    }

    // Internal function to burn tokens from an account
    function _burn(uint256 amount) internal virtual {
        accounts[msg.sender]._balances -= amount;
        _totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);

        emit Burn(msg.sender, amount);
    }

    // Function to renounce ownership, leaving the contract without an owner
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    // Function to transfer ownership of the contract to a new owner
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress(newOwner);

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // Function to get the current owner
    function owner() public view returns (address) {
        return _owner;
    }

    // Function to get the distribution details
    function getDistributionDetails()
        external
        view
        returns (Distribution[] memory)
    {
        return distributions;
    }

    function setBridgeAddress(address _bridgeAddress) external onlyOwner{
        _bridge = _bridgeAddress;
    }
}
