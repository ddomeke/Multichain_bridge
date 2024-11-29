// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract MultichainControl is CCIPReceiver, OwnerIsCreator {
    IRouterClient router;
    IERC20 public sourceTokenAddress;
    address private _owner; // Address of the contract owner

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    // Kullanıcıların kilitlediği token miktarlarını tutar
    mapping(address => uint256) public lockedTokens;

    event TokensTransferred(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );
    event TokensLocked(address indexed user, uint256 amount);
    event TokensUnlocked(uint256 amount);
    event MintCallSuccessfull();

    // Modifier to restrict the function to be executed only on Ethereum mainnet (chainId == 1)
    modifier onlyEthereum() {
        require(
            block.chainid == 1,
            "This function can only be executed on Ethereum Mainnet"
        );
        _;
    }

    constructor(address _router, address _sourceTokenAddress) CCIPReceiver(_router) {
        _owner = msg.sender;
        router = IRouterClient(_router);
        sourceTokenAddress = IERC20(_sourceTokenAddress);
    }

    // Token kilitleme fonksiyonu
    function lockTokens(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    ) external onlyOwner onlyEthereum returns (bytes32 messageId) {
        require(_amount > 0, "Amount should be greater than 0");

        if (_amount > sourceTokenAddress.balanceOf(msg.sender))
            revert NotEnoughBalance(sourceTokenAddress.balanceOf(msg.sender), _amount);


        lockedTokens[msg.sender] += _amount;

        // Approve Router to spend CCIP-BnM tokens we send
        IERC20(sourceTokenAddress).approve(address(this), _amount);

        // Token'ları kontrata transfer et
        IERC20(sourceTokenAddress).transferFrom(msg.sender, address(this), _amount);

        emit TokensLocked(msg.sender, _amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });
        tokenAmounts[0] = tokenAmount;

        // Build the CCIP Message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encodeWithSignature(
                "mint(address, uint256)",
                msg.sender,
                _amount
            ),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV2({
                    gasLimit: 0, // Gas limit for the callback on the destination chain
                    allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                })
            ),
            feeToken: address(0)
        });

        // Get the fee required to send the message
        uint256 fees = router.getFee(_destinationChainSelector, message);

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        // Approve Router to spend CCIP-BnM tokens we send
        IERC20(_token).approve(address(router), _amount);

        // Send CCIP Message
        messageId = router.ccipSend(_destinationChainSelector, message);

        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            address(0),
            fees
        );
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {

        uint256 amount = message.destTokenAmounts[0].amount;

        require(lockedTokens[_owner] >= amount, "Not enough locked tokens");
        lockedTokens[_owner] -= amount;

        IERC20(sourceTokenAddress).approve(address(this), amount);

        (bool success, ) = address(sourceTokenAddress).call(message.data);
        require(success, "Token transfer failed"); 
   
        emit TokensUnlocked(amount);
    }

    
    function setSourceAddress(address _sourceTokenAddress) external onlyOwner {
        sourceTokenAddress = IERC20(_sourceTokenAddress);
    }
}
