/**
 * @title Peniwallet
 * @dev Peniwallet is a contract for managing and
 * executing gasless transaction on the peniwallet mobile app
 *
 * @author geofferyj
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./verifier.sol";

/**
 * @title IErc20
 * @dev Interface for the ERC20 standard token.
 */
interface IErc20 {
    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address who) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
}

/**
 * @title IPancakeRouter
 * @dev Interface for the PancakeSwap Router
 */
interface IPancakeRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface IPancakeFactory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

/**
 * @title Peniwallet
 * @dev Peniwallet is a contract for managing and
 * executing gasless transaction on the peniwallet mobile app
 *
 * @author geofferyj
 * @notice This contract is a work in progress and is not yet
 * ready for production use.
 */

contract Peniwallet is EIP712Verifier {
    address private constant PancakeSwapRouterAddress =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    
    address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    /**
     * @dev stores admins
     */
    mapping(address => bool) public admins;

    /**
     * @dev address of the fee wallet
     */
    address public FEE_WALLET;

    /**
     * @notice mapping of projects to developers
     */
    mapping(address => address) public projects;

    /**
     * @dev fee % charged on each transaction
     */
    uint256 public feeRatio;

    /**
     * @dev minimum fee charged on each transaction
     */
    uint256 public minFee;

    /**
     * @dev fee multiplier based on the type of transaction
     */
    mapping(uint256 => uint256) public feeMultiplier;

    /**
     * @dev Transaction type for transfer
     */
    uint256 public constant TRANSFER = 0;

    /**
     * @dev Transaction type for swap
     */
    uint256 public constant SWAP = 1;

    /**
     * @dev Transaction type for spray
     */
    uint256 public constant SPRAY = 2;

    /**
     * @dev Emitted when gas is sent to a user
     */
    event GasSent(address indexed sender, address receiver, uint256 amount);

    /**
     * @dev Emitted when an admin is added
     */
    event AdminAdded(address indexed admin, address indexed addedBy);

    /**
     * @dev Emitted when an admin is removed
     */
    event AdminRemoved(address indexed admin, address indexed removedBy);

    /**
     * @dev Emitted when the minimum fee is set
     */
    event MinFeeSet(uint256 minFee, address indexed setBy);

    /**
     * @dev Emitted when the fee multiplier is set
     */
    event FeeMultiplierSet(
        uint256 feeMultiplier,
        uint256 indexed transactionType,
        address indexed setBy
    );

    /**
     * @dev Constructor
     * @param _transferFee the fee charged on transfers
     * @param _swapFee the fee charged on swaps
     * @param _sprayFee the fee charged on sprays
     * @param _minFee the minimum fee charged on all transactions
     */
    constructor(
        uint256 _transferFee,
        uint256 _swapFee,
        uint256 _sprayFee,
        uint256 _minFee
    ) {
        admins[msg.sender] = true;
        setFeeMultiplier(TRANSFER, _transferFee);
        setFeeMultiplier(SWAP, _swapFee);
        setFeeMultiplier(SPRAY, _sprayFee);
        setMinFee(_minFee);
        setFeeWallet(msg.sender);
    }

    /**
     * @dev Modifier to check if the caller is an admin
     */
    modifier onlyAdmin() {
        require(admins[msg.sender], "Only admins can call this function");
        _;
    }

    /**
     * @dev function to add an admin
     * @param _admin the address of the admin to add
     */
    function addAdmin(address _admin) public onlyAdmin {
        admins[_admin] = true;
        emit AdminAdded(_admin, msg.sender);
    }

    /**
     * @dev function to remove an admin
     * @param _admin the address of the admin to remove
     */
    function removeAdmin(address _admin) public onlyAdmin {
        admins[_admin] = false;
        emit AdminRemoved(_admin, msg.sender);
    }

    /**
     * @dev function to set the minimum fee
     * @param _minFee the minimum fee to set
     */
    function setMinFee(uint256 _minFee) public onlyAdmin {
        minFee = _minFee;
        emit MinFeeSet(_minFee, msg.sender);
    }

    /**
     * @dev function to set the fee wallet
     * @param _feeWallet the address of the fee wallet
     */
    function setFeeWallet(address _feeWallet) public onlyAdmin {
        FEE_WALLET = _feeWallet;
    }

    /**
     * @dev function to set the fee multiplier
     * @param _type the type of transaction
     * @param _multiplier the multiplier to set
     */
    function setFeeMultiplier(
        uint256 _type,
        uint256 _multiplier
    ) public onlyAdmin {
        feeMultiplier[_type] = _multiplier;
        emit FeeMultiplierSet(_multiplier, _type, msg.sender);
    }

    /**
     * @dev function to send gas to a user
     * the gas is sent from the contract to the user
     * @param _user the address of the user
     * @notice this function is only callable by admins
     */
    function sendGas(address _user) public payable onlyAdmin {
        require(msg.value > 0, "Amount must be greater than 0");

        payable(_user).transfer(msg.value);
        emit GasSent(msg.sender, _user, msg.value);
    }

    /**
     * @dev function to calculate the min fee in tokens
     * @param _token the address of the token to transfer
     * @param _amount the amount of tokens to transfer
     * @return _minFeeInToken the minimum fee in tokens
     * @notice function is private because it is only used internally
     */

    function _calculateMinFee(
        address _token,
        uint256 _amount
    ) private view returns (uint256 _minFeeInToken) {
        IPancakeRouter router = IPancakeRouter(PancakeSwapRouterAddress);
        if (_token == address(0)) {
            return minFee;
        }

        if (_token == router.WETH()) {
            return minFee;
        }

        address bnbTokenPair = IPancakeFactory(router.factory()).getPair(_token, router.WETH());
        address usdtTokenPair = IPancakeFactory(router.factory()).getPair(_token, USDT);
        address bnbUsdtPair = IPancakeFactory(router.factory()).getPair(router.WETH(), USDT);

        require(bnbTokenPair != address(0) && usdtTokenPair != address(0), "Pair does not exist");

        if (bnbTokenPair != address(0)){
            uint256 bnbReserve = IErc20(router.WETH()).balanceOf(bnbTokenPair);
            uint256 tokenReserve = IErc20(_token).balanceOf(bnbTokenPair);
            _minFeeInToken = router.quote(minFee, bnbReserve, tokenReserve);
        } else{
            /**
             * @dev if the token is not paired with BNB, then it is paired with USDT
             * @dev calculate the fee in USDT and then convert to token
             */
            uint256 usdtReserveInBNBPair = IErc20(USDT).balanceOf(bnbUsdtPair);
            uint256 bnbReserveInBNBPair = IErc20(router.WETH()).balanceOf(bnbUsdtPair);
            uint256 feeInUsdt = router.quote(minFee, bnbReserveInBNBPair, usdtReserveInBNBPair);

            uint256 tokenReserveInUSDTPair = IErc20(_token).balanceOf(usdtTokenPair);
            uint256 usdtReserveInTokenPair = IErc20(USDT).balanceOf(usdtTokenPair);
            _minFeeInToken = router.quote(feeInUsdt, usdtReserveInTokenPair, tokenReserveInUSDTPair);
        }

    }

    /**
     * @dev function to calculate the fee charged on a transaction
     * @param _token the address of the token
     * @param _amount the amount of tokens to transfer
     * @param _type the type of transaction
     * @return fee the fee charged
     * @notice function is private because it is only used internally
     */

    function _calculateFee(
        address _token,
        uint256 _amount,
        uint256 _type
    ) private view returns (uint256) {
        uint256 feeDecimals = 3;
        uint256 _feeRatio = feeMultiplier[_type];

        uint256 fee = ((_amount * 10 ** feeDecimals) * _feeRatio) /
            (100 * 10 ** feeDecimals);

        fee = fee / (10 ** feeDecimals);

        uint256 minFeeInToken = _calculateMinFee(_token, _amount);

        if (fee < minFeeInToken) {
            fee = minFeeInToken;
        }
        return fee;
    }

    /**
     * @dev function to dispatch fees to the fee wallet and dev wallet
     * @param _token the address of the token
     * @param _amount the amount of fees to transfer
     */
    function shareFees(address _token, uint256 _amount) private {
        // get project developer
        address developer = projects[_token];

        if (developer == address(0)) {
            IErc20(_token).transfer(FEE_WALLET, _amount);
        } else {
            uint256 devFee = (_amount * 25) / 100;
            IErc20(_token).transfer(developer, devFee);
            IErc20(_token).transfer(FEE_WALLET, _amount - devFee);
        }
    }

    /**
     * @dev function to transfer tokens for user
     * @param _token the address of the token to transfer
     * @param _from the address of the user to transfer from
     * @param _to the address of the user to transfer to
     * @param _amount the amount of tokens to transfer
     * @param _nonce the nonce of the transaction
     * @param _deadline the deadline of the transaction
     * @param _signature the signature of the transaction
     */
    function transfer(
        address _token,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature
    ) public {
        // check if the deadline has passed
        require(block.timestamp <= _deadline, "Transaction has expired");

        // check if the signature is valid
        TransferTransaction memory txn;
        txn.token = _token;
        txn.from = _from;
        txn.to = _to;
        txn.amount = _amount;
        txn.nonce = _nonce;
        txn.deadline = _deadline;

        require(
            verifyTransfer(txn, _signature),
            "Invalid signature: Signer is not the sender"
        );

        // check if the sender has enough tokens
        require(
            IErc20(_token).balanceOf(_from) >= _amount,
            "Insufficient balance"
        );
        
        require(minFee < _amount, "transaction will be underpriced");

        // check that the contract has enough allowance
        require(
            IErc20(_token).allowance(_from, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // calculate the fee
        uint256 fee = _calculateFee(_token, _amount, TRANSFER);

        // transfer the tokens
        IErc20(_token).transferFrom(_from, _to, _amount - fee);

        // transfer the fee
        shareFees(_token, fee);
    }

    /**
     * @dev function to swap BNB for tokens
     * @param _token the address of the token to receive
     */
    function swapBNBForTokens(address _token) public payable {
        IPancakeRouter router = IPancakeRouter(PancakeSwapRouterAddress);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: msg.value
        }(0, path, msg.sender, block.timestamp + 360);
    }

    /**
     * @dev function to swap tokens for BNB
     * @param _token the address of the token to swap
     * @param _user the address of the user
     * @param _amount the amount of tokens to swap
     * @param _nonce the nonce of the transaction
     * @param _deadline the deadline of the transaction
     * @param _signature the signature of the transaction
     */
    function swapTokensForBNB(
        address _token,
        address _user,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature
    ) public {
        IPancakeRouter router = IPancakeRouter(PancakeSwapRouterAddress);
        IErc20 token = IErc20(_token);

        // check if the deadline has passed
        require(block.timestamp <= _deadline, "Transaction has expired");

        // check if the signature is valid
        require(
            verifySwap(
                SwapTransaction({
                    tokenA: _token,
                    tokenB: router.WETH(),
                    from: _user,
                    amountA: _amount,
                    amountB: _amount,
                    nonce: _nonce,
                    deadline: _deadline
                }),
                _signature
            ),
            "Invalid signature"
        );

        // fee calculation
        uint256 fee = _calculateFee(_token, _amount, SWAP);

        // check that user has enough tokens
        require(token.balanceOf(_user) >= _amount, "Insufficient balance");


        // ensure fee is greater than min fee
        require(minFee < _amount, "transaction will be underpriced");

        // check that the contract has enough allowance
        require(
            token.allowance(_user, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // transfer the tokens to contract
        token.transferFrom(_user, address(this), _amount);

        // approve pancakeswap router
        if (
            token.allowance(address(this), PancakeSwapRouterAddress) <
            _amount
        ) {
            token.approve(PancakeSwapRouterAddress, token.totalSupply());
        }

        // swap the tokens
        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amount - fee,
            0,
            path,
            _user,
            block.timestamp + 360
        );

        // transfer the fee
        shareFees(_token, fee);

    }


    /**
     * @dev function to swap tokens for tokens
     * @param _path[]  an array of token addresses for the path the swap will take
     * @param _user the address of the sender
     * @param _amount the amount of tokens to swap
     * @param _nonce the nonce of the transaction
     * @param _deadline the deadline of the transaction
     * @param _signature the signature of the transaction
     */
    function swapTokensForTokens(
        address[] memory _path,
        address _user,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature
    ) public {
        IPancakeRouter router = IPancakeRouter(PancakeSwapRouterAddress);
        IErc20 token = IErc20(_path[0]);

        // check if the deadline has passed
        require(block.timestamp <= _deadline, "Transaction has expired");

        // check if the signature is valid
        require(
            verifySwap(
                SwapTransaction({
                    tokenA: _path[0],
                    tokenB: _path[_path.length - 1],
                    from: _user,
                    amountA: _amount,
                    amountB: _amount,
                    nonce: _nonce,
                    deadline: _deadline
                }),
                _signature
            ),
            "Invalid signature"
        );

        // check that user has enough tokens
        require(token.balanceOf(_user) >= _amount, "Insufficient balance");

        // ensure fee is greater than min fee
        require(minFee < _amount, "transaction will be underpriced");

        // fee calculation
        uint256 fee = _calculateFee(_path[0], _amount, SWAP);


        // check that the contract has enough allowance
        require(
            token.allowance(_user, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // transfer the tokens to contract
        token.transferFrom(_user, address(this), _amount);

        // approve pancakeswap router
        if (
            token.allowance(address(this), PancakeSwapRouterAddress) <
            _amount
        ) {
            token.approve(PancakeSwapRouterAddress, token.totalSupply());
        }

        // swap the tokens
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount - fee,
            0,
            _path,
            _user,
            block.timestamp + 360
        );

        // transfer the fee
        shareFees(_path[0], fee);
    }


    /**
     * @notice Sprays tokens to multiple addresses
     * @dev This function allows you to spray tokens to multiple addresses
     * @return success returns true if the spray was successful
     * @param _token the address of the token to spray
     * @param _from the address of the user to spray from
     * @param _recipients  the addresses to spray
     * @param _amount the amount of tokens to spray to each address
     * @param _nonce the nonce of the transaction
     * @param _deadline the deadline of the transaction
     * @param _signature the signature of the transaction
     */

    function sprayToken(
        address _token,
        address _from,
        address[] memory _recipients,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature
    ) public returns (bool success) {
        IErc20 token = IErc20(_token);
        uint256 spray_value = _amount * (10 ** uint256(token.decimals()));
        uint256 total = spray_value * _recipients.length;
        uint256 fee = _calculateFee(_token, total, SPRAY);

        // check that the recipient list is <= 200
        require(_recipients.length <= 200, "Recipient list is too long");

        // check if the deadline has passed
        require(block.timestamp <= _deadline, "Transaction has expired");

        // check if the signature is valid
        SprayTransaction memory txn;
        txn.token = _token;
        txn.from = _from;
        txn.receivers = _recipients;
        txn.amount = _amount;
        txn.nonce = _nonce;
        txn.deadline = _deadline;

        require(
            verifySpray(txn, _signature),
            "Invalid signature: Signer is not the sender"
        );

        // check balance
        require(token.balanceOf(_from) >= total + fee, "insufficient balance");

        // check allowance
        require(
            token.allowance(_from, address(this)) >= total + fee,
            "insufficient allowance"
        );

        // transfer the fee
        token.transferFrom(_from, address(this), fee);

        for (uint i = 0; i < _recipients.length; i++) {
            token.transferFrom(_from, _recipients[i], spray_value);
        }

        return true;
    }

    /**
     * @notice Sprays BNB to multiple addresses
     * @dev This function allows you to spray BNB to multiple addresses
     * @return success returns true if the spray was successful
     * @param _recipients  the addresses to spray
     * @param value the amount of BNB to spray to each address
     */
    function sprayCoin(
        address[] memory _recipients,
        uint256 value
    ) public payable returns (bool success) {
        uint256 spray_value = value * (10 ** 18);
        uint256 total = spray_value * _recipients.length;
        uint256 fee = _calculateFee(address(0), total, SPRAY);

        // check that user has enough BNB
        require(msg.value >= total + fee, "Insufficient balance");

        // check that the recipient list is <= 200
        require(_recipients.length <= 200, "Recipient list is too long");

        // transfer the fee

        for (uint i = 0; i < _recipients.length; i++) {
            payable(_recipients[i]).transfer(spray_value);
        }

        payable(FEE_WALLET).transfer(fee);
        return true;
    }

    function estimateFees(
        address _token,
        uint256 _amount,
        uint256 _type
    ) public view returns (uint256) {
        return _calculateFee(_token, _amount, _type);
    }

    /**
     * @dev function to withdraw BNB from the contract
     * @notice this function is only callable by admins
     */
    function withdrawBNB() public onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev function to withdraw tokens from the contract
     * @param _token the address of the token to withdraw
     * @notice this function is only callable by admins
     */
    function withdrawTokens(address _token) public onlyAdmin {
        IErc20(_token).transfer(
            msg.sender,
            IErc20(_token).balanceOf(address(this))
        );
    }

    receive() external payable {}

    fallback() external payable {}
}
