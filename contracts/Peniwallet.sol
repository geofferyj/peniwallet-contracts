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
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
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
    address public PancakeSwapRouterAddress;

    address public USDT;

    /**
     * @dev stores admins
     */
    mapping(address => bool) public admins;

    /**
     * @notice mapping of projects to developers
     */
    //      token     developer
    mapping(address => address) public projects;

    /**
     * @dev struct to store the project details and fee withdrawal details
     */
    struct Fee {
        address owner;
        address token;
        uint256 balance;
        uint256 lastWithdrawal;
    }

    /**
     * @dev mapping of projects to fees and details
     */
    //      token      list of fee details
    mapping(address => Fee[]) public fees;

    /**
     * @dev minimum fee charged on each transaction
     */
    uint256 public minFee;

    /**
     * @dev developer fee share
     */
    uint256 public devFeeShare = 10;

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
     * @dev Nonces for each tracsaction
     */

    mapping(address => uint256) nonces;

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
     * @dev dev fee share Changed
     */
    event DevFeeShareSet(
        uint256 devFeeShare,
        address indexed setBy,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a project is created
     */
    event ProjectRegistered(
        address indexed projectOwner,
        address indexed projectAddress,
        address indexed createdBy
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
        uint256 _minFee,
        address _PancakeSwapRouterAddress,
        address _USDT
    ) {
        admins[msg.sender] = true;
        setFeeMultiplier(TRANSFER, _transferFee);
        setFeeMultiplier(SWAP, _swapFee);
        setFeeMultiplier(SPRAY, _sprayFee);
        setMinFee(_minFee);
        PancakeSwapRouterAddress = _PancakeSwapRouterAddress;
        USDT = _USDT;
    }

    /**
     * @dev Modifier to check if the caller is an admin
     */
    modifier onlyAdmin() {
        require(admins[msg.sender], "Only admins can call this function");
        _;
    }

    // Nonce Management

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
     * @dev function to set the dev fee share
     * @param _devFeeShare the dev fee share to set
     */
    function setDevFeeShare(uint256 _devFeeShare) public onlyAdmin {
        devFeeShare = _devFeeShare;
        emit DevFeeShareSet(_devFeeShare, msg.sender, block.timestamp);
    }

    /**
     * @dev function to register a project
     * @param _projectOwner the address of the project owner
     * @param _projectAddress the address of the project
     */
    function registerProject(
        address _projectOwner,
        address _projectAddress
    ) public onlyAdmin {
        projects[_projectAddress] = _projectOwner;
        // create fee for project
        Fee memory newFee = Fee({
            owner: _projectOwner,
            token: _projectAddress,
            balance: 0,
            lastWithdrawal: block.timestamp
        });

        fees[_projectOwner].push(newFee);

        emit ProjectRegistered(_projectOwner, _projectAddress, msg.sender);
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
     * @notice function to get fee details by owner and token
     * @param _owner the dev of the token
     * @param _token the token address
     */

    function getFeeByAddress(
        address _owner,
        address _token
    ) public view returns (Fee memory) {
        Fee memory fee;
        for (uint256 i = 0; i < fees[_owner].length; i++) {
            if (fees[_owner][i].token == _token) {
                fee = fees[_owner][i];
                break;
            }
        }
        return fee;
    }

    /**
     * @dev function to calculate the min fee in tokens
     * @param _token the address of the token to transfer
     * @return _minFeeInToken the minimum fee in tokens
     * @notice function is private because it is only used internally
     */

    function _calculateMinFee(
        address _token
    ) private view returns (uint256 _minFeeInToken) {
        IPancakeRouter router = IPancakeRouter(PancakeSwapRouterAddress);
        IPancakeFactory factory = IPancakeFactory(router.factory());

        if (_token == address(0)) {
            return minFee;
        }

        if (_token == router.WETH()) {
            return minFee;
        }

        address bnbTokenPair = factory.getPair(_token, router.WETH());
        address usdtTokenPair = factory.getPair(_token, USDT);
        address bnbUsdtPair = factory.getPair(router.WETH(), USDT);

        require(
            bnbTokenPair != address(0) || usdtTokenPair != address(0),
            "No Supported Pairs exists for the token"
        );

        if (bnbTokenPair != address(0)) {
            uint256 bnbReserve = IErc20(router.WETH()).balanceOf(bnbTokenPair);
            uint256 tokenReserve = IErc20(_token).balanceOf(bnbTokenPair);
            _minFeeInToken = router.quote(minFee, bnbReserve, tokenReserve);
        } else {
            /**
             * @dev if the token is not paired with BNB, then it is paired with USDT
             * @dev calculate the fee in USDT and then convert to token
             */
            uint256 usdtReserveInBNBPair = IErc20(USDT).balanceOf(bnbUsdtPair);
            uint256 bnbReserveInBNBPair = IErc20(router.WETH()).balanceOf(
                bnbUsdtPair
            );
            uint256 feeInUsdt = router.quote(
                minFee,
                bnbReserveInBNBPair,
                usdtReserveInBNBPair
            );

            uint256 tokenReserveInUSDTPair = IErc20(_token).balanceOf(
                usdtTokenPair
            );
            uint256 usdtReserveInTokenPair = IErc20(USDT).balanceOf(
                usdtTokenPair
            );
            _minFeeInToken = router.quote(
                feeInUsdt,
                usdtReserveInTokenPair,
                tokenReserveInUSDTPair
            );
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

        // Calculate the fee based on the transaction amount and fee ratio
        uint256 fee = ((_amount * 10 ** feeDecimals) * _feeRatio) /
            (100 * 10 ** feeDecimals);

        // Adjust fee to the proper decimal representation
        fee = fee / (10 ** feeDecimals);

        // Get the minimum fee in tokens (commented out for demonstration purposes)
        uint256 minFeeInToken = _calculateMinFee(_token);

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
        uint256 devFee = (_amount * devFeeShare) / 100;
        uint256 fee = _amount - devFee;

        if (developer == address(0)) {
            fee = _amount;
        } else {
            for (uint256 i = 0; i < fees[developer].length; i++) {
                if (fees[developer][i].token == _token) {
                    fees[developer][i].balance += devFee;
                    break;
                }
            }
        }

        if (fees[address(this)].length == 0) {
            Fee memory newFee = Fee({
                owner: address(this),
                token: _token,
                balance: fee,
                lastWithdrawal: 0
            });
            fees[address(this)].push(newFee);
            return;
        }

        for (uint256 i = 0; i < fees[address(this)].length; i++) {
            if (fees[address(this)][i].token == _token) {
                fees[address(this)][i].balance += _amount;
                break;
            } else if (i == fees[address(this)].length - 1) {
                Fee memory newFee = Fee({
                    owner: address(this),
                    token: _token,
                    balance: fee,
                    lastWithdrawal: 0
                });
                fees[address(this)].push(newFee);
            }
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
        IErc20 token = IErc20(_token);
        // check if the deadline has passed
        require(block.timestamp <= _deadline, "Transaction has expired");

        // check if the signature is valid
        require(
            verifyTransfer(
                TransferTransaction({
                    token: _token,
                    from: _from,
                    to: _to,
                    amount: _amount,
                    nonce: _nonce,
                    deadline: _deadline
                }),
                _signature
            ),
            "Invalid signature: Signer is not the sender"
        );

        // check if the sender has enough tokens
        require(token.balanceOf(_from) >= _amount, "Insufficient balance");

        // check if there is enough value for fee and amount
        require(minFee < _amount, "transaction is underpriced");

        // check that the contract has enough allowance
        require(
            token.allowance(_from, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // calculate the fee
        uint256 fee = _calculateFee(_token, _amount, TRANSFER);

        // transfer the tokens
        token.transferFrom(_from, _to, _amount - fee);

        // transfer the fee
        token.transferFrom(_from, address(this), fee);

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
        require(minFee < _amount, "transaction is underpriced");

        // check that the contract has enough allowance
        require(
            token.allowance(_user, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // transfer the tokens to contract
        token.transferFrom(_user, address(this), _amount);

        // approve pancakeswap router
        if (
            token.allowance(address(this), PancakeSwapRouterAddress) < _amount
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
            token.allowance(address(this), PancakeSwapRouterAddress) < _amount
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
            verifySpray(
                SprayTransaction({
                    token: _token,
                    from: _from,
                    receivers: _recipients,
                    amount: _amount,
                    nonce: _nonce,
                    deadline: _deadline
                }),
                _signature
            ),
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

        // transfer the fee
        shareFees(_token, fee);
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

        payable(address(this)).transfer(fee);
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
     * @dev function to withdraw fees
     * @param _token the address of the token to withdraw
     */
    function withdrawFees(address _token) public {
        require(
            projects[_token] == msg.sender,
            "Only project owner can call this function"
        );

        Fee memory fee;
        for (uint256 i = 0; i < fees[msg.sender].length; i++) {
            if (fees[msg.sender][i].token == _token) {
                fee = fees[msg.sender][i];
                break;
            }
        }

        require(fee.balance > 0, "Insufficient balance");

        uint256 amount = fee.balance;
        fee.balance = 0;
        fee.lastWithdrawal = block.timestamp;

        IErc20(_token).transfer(msg.sender, amount);
    }

    /**
     * @dev function to withdraw BNB from the contract
     * @notice this function is only callable by admins
     */
    function withdrawBNB() public onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev function to withdraw admin fees
     * @param _token the address of the token to withdraw
     */
    function withdrawAdminFees(address _token) public onlyAdmin{
        

        Fee memory fee;
        for (uint256 i = 0; i < fees[address(this)].length; i++) {
            if (fees[address(this)][i].token == _token) {
                fee = fees[address(this)][i];
                break;
            }
        }

        require(fee.balance > 0, "Insufficient balance");

        uint256 amount = fee.balance;
        fee.balance = 0;
        fee.lastWithdrawal = block.timestamp;

        IErc20(_token).transfer(msg.sender, amount);
    }

    /**
     * @dev function to recover expired fees
     * @param _token the address of the token to withdraw
     */
    function recoverFees(address _token)public onlyAdmin{
        address dev = projects[_token];

        Fee memory fee;
        for (uint256 i = 0; i < fees[dev].length; i++) {
            if (fees[dev][i].token == _token) {
                fee = fees[dev][i];
                break;
            }
        }

        require(fee.lastWithdrawal + 365 days < block.timestamp, "Fee has not expired");
        require(fee.balance > 0, "Insufficient balance");

        IErc20(_token).transfer(msg.sender, fee.balance);
    }
    
    receive() external payable {}

    fallback() external payable {}
}
