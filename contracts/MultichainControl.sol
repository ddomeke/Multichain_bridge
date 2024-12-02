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

    constructor(
        address _router,
        address _sourceTokenAddress
    ) CCIPReceiver(_router) {
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
    ) external onlyOwner returns (bytes32 messageId) {
        require(_amount > 0, "Amount should be greater than 0");

        require(_amount < sourceTokenAddress.balanceOf(msg.sender), "Amount should be greater than balanceOf(msg.sender)");

        lockedTokens[msg.sender] += _amount;

        IERC20(sourceTokenAddress).approve(address(this), _amount);

        uint256 allowance = IERC20(sourceTokenAddress).allowance(msg.sender, address(this));
        require(allowance >= _amount, "Allowance too low for contract to spend tokens");

        bool transferSuccess = IERC20(sourceTokenAddress).transferFrom(msg.sender, address(this), _amount);
        require(transferSuccess, "Token transfer failed");

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
                Client.EVMExtraArgsV1({gasLimit: 2000000}) // Additional arguments, setting gas limit and non-strict sequency mode
            ),
            feeToken: address(0)
        });


        // Get the fee required to send the message
        uint256 fees = router.getFee(_destinationChainSelector, message);
        require(fees <= address(this).balance, "Not enough contract balance for fee");


        // Approve Router to spend CCIP-BnM tokens we send
        bool approveRouterSuccess = IERC20(_token).approve(address(router), _amount);
        require(approveRouterSuccess, "Approve Router failed");

        uint256 tokenAllowance = IERC20(_token).allowance(msg.sender, address(router));
        require(tokenAllowance >= _amount, "Router allowance is insufficient");

        // Send CCIP Message
        messageId = router.ccipSend{value: fees}(_destinationChainSelector, message);

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
