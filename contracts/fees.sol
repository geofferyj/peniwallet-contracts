contract FeesTest{

    struct Fee {
        address owner;
        address token;
        uint256 balance;
        uint256 lastWithdrawal;
    }

    //      token    =>  dev
    mapping(address => address) public projects;

    //      dev     =>           token  => fee
    mapping(address => mapping (address => Fee)) public fees;

    uint256 public devFeeShare = 10;

    function getFee(address _token) public view returns (uint256) {
        return fees[msg.sender][_token].balance;
    }

    function getFee(address _token, address _dev) public view returns (uint256) {
        return fees[_dev][_token].balance;
    }
    
    // function getFees(address _dev) public view returns {
    //     return fees[_dev];
    // }


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

    function registerProject(address _token, address _dev) public {
        projects[_token] = _dev;
        fees[_dev][_token].owner = _dev;
        fees[_dev][_token].token = _token;
    }

    function withdrawFees(address _token) public {
        Fee storage fee = fees[msg.sender][_token];
        require(fee.balance > 0, "No fees to withdraw");


        fee.lastWithdrawal = block.timestamp;
        uint256 balanceToWithdraw = fee.balance;
        fee.balance = 0;


        require(ERC20(_token).transfer(msg.sender, balanceToWithdraw), "Transfer failed");

    }


    function getDevBalance(address _token) public view returns (uint256) {
        return fees[msg.sender][_token].balance;
    }
}