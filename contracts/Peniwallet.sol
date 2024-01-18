/**
 * @title Peniwallet
 * @dev Peniwallet is a contract for managing and
 * executing gasless transaction on the peniwallet mobile app
 *
 * @author geofferyj
 */

// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

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
     * @dev mapping of dev to projects to fees details
     */
    //      dev     =>           token  => fee
    mapping(address => mapping(address => Fee)) public fees;

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
     * @dev A mapping of spray signatures to bool for spray security 
    */
    mapping(bytes => bool) public spraySignatures;

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
     * @dev Emitted when a fee is withdrawn
     */
    event FeeWithdrawn(
        address indexed dev,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a spray is executed
     */
    event SprayExecuted(
        address indexed token,
        address indexed from,
        address[] receivers,
        uint256 amount,
        uint256 timestamp,
        string name,
        string code
    );

    /**
     * @dev Constructor
     * @param _transferFee the fee charged on transfers
     * @param _swapFee the fee charged on swaps
     * @param _sprayFee the fee charged on sprays
     */
    constructor(
        uint256 _transferFee,
        uint256 _swapFee,
        uint256 _sprayFee,
        address _PancakeSwapRouterAddress,
        address _USDT
    ) {
        admins[msg.sender] = true;
        setFeeMultiplier(TRANSFER, _transferFee);
        setFeeMultiplier(SWAP, _swapFee);
        setFeeMultiplier(SPRAY, _sprayFee);
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
    modifier checkNonce(address _from, uint256 _nonce) {
        require(_nonce == nonces[_from], "Invalid nonce");
        nonces[_from]++;
        _;
    }


    function getNonce(address _from) public view returns (uint256) {
        return nonces[_from];
    }

    /**
     * @dev modifier to check if the signature has been used for spray
    */
    modifier checkSpraySignature(bytes memory _signature) {
        require(!spraySignatures[_signature], "Spray already executed");
        spraySignatures[_signature] = true;
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
     * @dev function to set the dev fee share
     * @param _devFeeShare the dev fee share to set
     */
    function setDevFeeShare(uint256 _devFeeShare) public onlyAdmin {
        devFeeShare = _devFeeShare;
        emit DevFeeShareSet(_devFeeShare, msg.sender, block.timestamp);
    }

    /**
     * @dev function to register a project
     * @param _dev the address of the project owner
     * @param _token the address of the project
     */
    function registerProject(address _token, address _dev) public onlyAdmin {
        projects[_token] = _dev;
        fees[_dev][_token].owner = _dev;
        fees[_dev][_token].token = _token;
        emit ProjectRegistered(_dev, _token, msg.sender);
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
        return fees[_owner][_token];
    }

    /**
     * @dev function to calculate the min fee in tokens
     * @param _token the address of the token to transfer
     * @param minFee the minimum fee in BNB
     * @return _minFeeInToken the minimum fee in tokens
     * @notice function is private because it is only used internally
     */

    function _calculateMinFee(
        address _token,
        uint256 minFee
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
            
            // if the token is not paired with BNB, then it is paired with USDT
            // calculate the fee in USDT and then convert to token
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
     * @param _externalFee the gas fee charged by the network for the transaction
     * @return fee the fee charged
     * @notice function is private because it is only used internally
     */

    function _calculateFee(
        address _token,
        uint256 _amount,
        uint256 _type,
        uint256 _externalFee
    ) private view returns (uint256) {
        uint256 feeDecimals = 3;
        uint256 _feeRatio = feeMultiplier[_type];

        // Calculate the fee based on the transaction amount and fee ratio
        uint256 fee = ((_amount * 10 ** feeDecimals) * _feeRatio) /
            (100 * 10 ** feeDecimals);

        // Adjust fee to the proper decimal representation
        fee = fee / (10 ** feeDecimals);

        // Get the minimum fee in tokens
        uint256 minFeeInToken = _calculateMinFee(_token, _externalFee);
        return fee + minFeeInToken;
    }

    /**
     * @dev function to dispatch fees to the fee wallet and dev wallet
     * @param _token the address of the token
     * @param _amount the amount of fees to transfer
     */
    function shareFees(address _token, uint256 _amount) private {
        // get project developer
        address developer = projects[_token];
        uint256 fee;
        if (developer == address(0)) {
            fee = _amount;
        } else {
            uint256 devShare = (_amount * devFeeShare) / 100;
            fees[developer][_token].balance += devShare;
            fee = _amount - devShare;
        }

        if (fees[address(this)][_token].token == address(0)) {
            Fee memory newFee = Fee({
                owner: address(this),
                token: _token,
                balance: fee,
                lastWithdrawal: 0
            });
            fees[address(this)][_token] = newFee;
            return;
        }

        fees[address(this)][_token].balance += fee;
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
     * @param _gas the gas fee (in wie) charged by the network for the transaction
     */
    function transfer(
        address _token,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature,
        uint256 _gas
    ) public checkNonce(_from, _nonce) {
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

        // fee calculation
        uint256 fee = _calculateFee(_token, _amount, TRANSFER, _gas);
        // check if the sender has enough tokens
        require(
            token.balanceOf(_from) >= _amount + fee,
            "Insufficient balance for amount + fee"
        );

        // check that the contract has enough allowance
        require(
            token.allowance(_from, address(this)) >= _amount + fee,
            "Insufficient allowance"
        );

        // transfer the fee
        shareFees(_token, fee);

        // transfer the tokens
        token.transferFrom(_from, _to, _amount);

        // transfer the fee
        token.transferFrom(_from, address(this), fee);
    }

    /**
     * @dev function to swap BNB for tokens
     * @param _token the address of the token to receive
     */
    function swapBNBForTokens(
        address _token
    ) public payable {
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
     * @param _path the token path to swap
     * @param _user the address of the user
     * @param _amount the amount of tokens to swap
     * @param _nonce the nonce of the transaction
     * @param _deadline the deadline of the transaction
     * @param _signature the signature of the transaction
     * @param _gas the gas fee (in wie) charged by the network for the transaction
     */
    function swapTokensForBNB(
        address[] memory _path,
        address _user,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes memory _signature,
        uint256 _gas
    ) public checkNonce(_user, _nonce) {
        IPancakeRouter router = IPancakeRouter(PancakeSwapRouterAddress);
        IErc20 token = IErc20(_path[0]);

        // check if the deadline has passed
        require(block.timestamp <= _deadline, "Transaction has expired");

        // check if the signature is valid
        require(
            verifySwap(
                SwapTransaction({
                    tokenA: _path[0],
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
        uint256 fee = _calculateFee(_path[0], _amount, SWAP, _gas);

        // check that user has enough tokens
        require(
            token.balanceOf(_user) >= _amount + fee,
            "Insufficient balance for amount + fee"
        );

        // check that the contract has enough allowance
        require(
            token.allowance(_user, address(this)) >= _amount,
            "Insufficient allowance"
        );

        // approve pancakeswap router
        if (
            token.allowance(address(this), PancakeSwapRouterAddress) < _amount
        ) {
            token.approve(PancakeSwapRouterAddress, token.totalSupply());
        }

        // transfer the fee
        shareFees(_path[0], fee);


        // transfer the tokens to contract
        token.transferFrom(_user, address(this), _amount + fee);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            _user,
            block.timestamp + 360
        );
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
        bytes memory _signature,
        uint256 _gas
    ) public checkNonce(_user, _nonce) {
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

        // fee calculation
        uint256 fee = _calculateFee(_path[0], _amount, SWAP, _gas);

        // check that user has enough tokens
        require(
            token.balanceOf(_user) >= _amount + fee,
            "Insufficient balance for amount + fee"
        );

        // check that the contract has enough allowance
        require(
            token.allowance(_user, address(this)) >= _amount + fee,
            "Insufficient allowance"
        );

        // approve pancakeswap router
        if (
            token.allowance(address(this), PancakeSwapRouterAddress) < _amount
        ) {
            token.approve(PancakeSwapRouterAddress, token.totalSupply());
        }

        // share the fee
        shareFees(_path[0], fee);

        // transfer the tokens to contract
        token.transferFrom(_user, address(this), _amount + fee);

        // swap the tokens
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            _user,
            block.timestamp + 360
        );
    }

    /**
     * @notice Sprays tokens to multiple addresses
     * @dev This function allows you to spray tokens to multiple addresses
     * @return success returns true if the spray was successful
     * @param _token the address of the token to spray
     * @param _from the address of the user to spray from
     * @param _recipients  the addresses to spray
     * @param _amount the amount of tokens to spray to each address
     * @param _signature the signature of the transaction
     */

    function sprayToken(
        address _token,
        address _from,
        address[] memory _recipients,
        uint256 _amount, // for one address
        string memory _name,
        string memory _code,
        bytes memory _signature,
        uint256 _gas
    ) public checkSpraySignature(_signature) returns (bool success) {
        IErc20 token = IErc20(_token);
        uint256 total = _amount * _recipients.length;
        uint256 fee = _calculateFee(_token, total, SPRAY, _gas);

        // check that the recipient list is <= 200
        require(_recipients.length <= 200, "Recipient list is too long");

        // check if the signature is valid
        require(
            verifySpray(
                SprayTransaction({
                    token: _token,
                    from: _from,
                    receivers: _recipients,
                    amount: _amount,
                    code: _code
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
            token.transferFrom(_from, _recipients[i], _amount);
        }

        // transfer the fee charged
        shareFees(_token, fee);

        emit SprayExecuted(
            _token,
            _from,
            _recipients,
            _amount,
            block.timestamp,
            _name,
            _code
        );

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
        uint256 total = value * _recipients.length;
        uint256 fee = _calculateFee(address(0), total, SPRAY, 0);

        // check that user has enough BNB
        require(msg.value >= total + fee, "Insufficient balance");

        // check that the recipient list is <= 200
        require(_recipients.length <= 200, "Recipient list is too long");

        // transfer the fee
        for (uint i = 0; i < _recipients.length; i++) {
            payable(_recipients[i]).transfer(value);
        }

        payable(address(this)).transfer(fee);
        return true;
    }

    function estimateFees(
        address _token,
        uint256 _amount,
        uint256 _type,
        uint256 _gas
    ) public view returns (uint256) {
        return _calculateFee(_token, _amount, _type, _gas);
    }

    /**
     * @dev function to withdraw fees
     * @param _token the address of the token to withdraw
     */
    function withdrawFees(address _token) public {
        Fee storage fee = fees[msg.sender][_token];
        require(fee.balance > 0, "No fees to withdraw");
        fee.lastWithdrawal = block.timestamp;
        uint256 balanceToWithdraw = fee.balance;
        fee.balance = 0;

        require(
            IErc20(_token).transfer(msg.sender, balanceToWithdraw),
            "Transfer failed"
        );
        emit FeeWithdrawn(
            msg.sender,
            _token,
            balanceToWithdraw,
            block.timestamp
        );
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
    function withdrawAdminFees(address _token) public onlyAdmin {
        Fee memory fee = fees[address(this)][_token];

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
    function recoverFees(address _token) public onlyAdmin {
        address dev = projects[_token];

        Fee memory fee = fees[dev][_token];

        require(
            fee.lastWithdrawal + 365 days < block.timestamp,
            "Fee has not expired"
        );

        uint256 amount = IErc20(_token).balanceOf(address(this));
        require(amount > 0, "Insufficient balance");

        IErc20(_token).transfer(msg.sender, amount);
    }

    receive() external payable {}

    fallback() external payable {}
}
