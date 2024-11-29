// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ArbitrumBridge is CCIPReceiver, OwnerIsCreator {
    IRouterClient router;
    ERC20Burnable  public sourceTokenAddress;

    event MintCallSuccessfull();
    event TokensBurned(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    constructor(address _router, address _sourceTokenAddress) CCIPReceiver(_router) {
        router = IRouterClient(_router);
        sourceTokenAddress = ERC20Burnable(_sourceTokenAddress);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (bool success, ) = address(sourceTokenAddress).call(message.data);
        require(success, "Token mint failed");
        emit MintCallSuccessfull();
    }

       // Token kilitleme fonksiyonu
    function burnTokens(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    ) external onlyOwner returns (bytes32 messageId) {

        require(_amount > 0, "Amount should be greater than 0");
        
        if (_amount > sourceTokenAddress.balanceOf(msg.sender))
            revert NotEnoughBalance(sourceTokenAddress.balanceOf(msg.sender), _amount);

        ERC20Burnable(sourceTokenAddress).burn(_amount);

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
                "tranfer(address,address, uint256)",
                _receiver,
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

        emit TokensBurned(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            address(0),
            fees
        );
    }

    function setSourceAddress(address _sourceTokenAddress) external onlyOwner {
        sourceTokenAddress = ERC20Burnable(_sourceTokenAddress);
    }
}
