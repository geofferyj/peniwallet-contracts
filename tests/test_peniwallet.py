from eth_account import Account
import pytest
from brownie import Peniwallet, chain, web3, ERC20Mock, config, network
from brownie import accounts as _accounts
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_structured_data
from eth_account.signers.local import LocalAccount

@pytest.fixture(scope="module", autouse=True)
def accounts():
    if network.show_active() != "localnet":
        _accounts.add(config["wallets"]["account-0"])
        _accounts.add(config["wallets"]["account-1"])
        _accounts.add(config["wallets"]["account-2"])
    return _accounts

def prepare_transfer_data(contract, token, accounts, amount = 500):
    message_data = {
        'token': token,
        'from': accounts[0].address,
        'to': accounts[1].address,
        'amount': amount,
        'nonce': web3.eth.get_transaction_count(accounts[0].address),
        'deadline': chain.time() + 3600
    }
    message = {
        'types': {
            'EIP712Domain': [
                {'name': 'name', 'type': 'string'},
                {'name': 'version', 'type': 'string'},
                {'name': 'chainId', 'type': 'uint256'},
                {'name': 'verifyingContract', 'type': 'address'},
            ],
            'TransferTransaction': [
                {'name': 'token', 'type': 'address'},
                {'name': 'from', 'type': 'address'},
                {'name': 'to', 'type': 'address'},
                {'name': 'amount', 'type': 'uint256'},
                {'name': 'nonce', 'type': 'uint256'},
                {'name': 'deadline', 'type': 'uint256'},
            ],
        },
        'message': message_data,
        'primaryType': 'TransferTransaction',
        'domain': {
            'name': 'Peniwallet',
            'version': '1',
            'chainId': chain.id,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': contract,
        }
    }

    account: LocalAccount = Account.from_key(accounts[0].private_key)
    encoded_message = encode_structured_data(message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data

def prepare_swap_data(contract, token, accounts, amount = 500):
    message_data = {
        'tokenA': token,
        'tokenB': "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
        'from': accounts[0].address,
        'amountA': amount,
        'amountB': amount,
        'nonce': web3.eth.get_transaction_count(accounts[0].address),
        'deadline': chain.time() + 3600
    }
    message = {
        'types': {
            'EIP712Domain': [
                {'name': 'name', 'type': 'string'},
                {'name': 'version', 'type': 'string'},
                {'name': 'chainId', 'type': 'uint256'},
                {'name': 'verifyingContract', 'type': 'address'},
            ],
            'SwapTransaction': [
                {'name': 'tokenA', 'type': 'address'},
                {'name': 'tokenB', 'type': 'address'},
                {'name': 'from', 'type': 'address'},
                {'name': 'amountA', 'type': 'uint256'},
                {'name': 'amountB', 'type': 'uint256'},
                {'name': 'nonce', 'type': 'uint256'},
                {'name': 'deadline', 'type': 'uint256'},
            ],
        },
        'message': message_data,
        'primaryType': 'SwapTransaction',
        'domain': {
            'name': 'Peniwallet',
            'version': '1',
            'chainId': chain.id,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': contract,
        }
    }

    account: LocalAccount = Account.from_key(accounts[0].private_key)
    encoded_message = encode_structured_data(message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data

@pytest.fixture(scope="module")
def peniwallet(accounts):
    # return Peniwallet.deploy(1700, 2000, 5000, 100, {'from': accounts[0]})
    return Peniwallet.at('0x85eaAc08bd9203f42715527CC4258cE759F4C243')

@pytest.fixture(scope="module")
def token(accounts):
    # USDT
    # return ERC20Mock.at('0x55d398326f99059fF775485246999027B3197955')

    # WKC
    return ERC20Mock.at('0x6ec90334d89dbdc89e08a133271be3d104128edb')

def test_add_admin(peniwallet, accounts):
    # Add an admin
    peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Check that the admin was added
    assert peniwallet.admins(accounts[1]) == True

def test_remove_admin(peniwallet, accounts):
    # Add an admin
    peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Remove the admin
    peniwallet.removeAdmin(accounts[1], {'from': accounts[0]})

    # Check that the admin was removed
    assert peniwallet.admins(accounts[1]) == False

def test_set_min_fee(peniwallet, accounts):
    # Set the minimum fee
    peniwallet.setMinFee(100, {'from': accounts[0]})

    # Check that the minimum fee was set
    assert peniwallet.minFee() == 100

def test_set_fee_multiplier(peniwallet, accounts):
    # Set the fee multiplier
    peniwallet.setFeeMultiplier(1, 2, {'from': accounts[0]})

    # Check that the fee multiplier was set
    assert peniwallet.feeMultiplier(1) == 2

def test_send_gas(peniwallet, accounts):

    old_balance = accounts[1].balance()
    # Send gas to a user
    peniwallet.sendGas(accounts[1], {'from': accounts[0], 'value': 10})

    # Check that the gas was sent
    assert accounts[1].balance() == old_balance + 10

def test_transfer(peniwallet, token, accounts):

    # Approve the Peniwallet contract to spend the sender's tokens
    # token.approve(peniwallet.address, token.totalSupply(), {'from': accounts[0]})

    # Generate a signature for the transfer
    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts, 1000000)
    print(f"signature: {signature}")
    print(f"message_data: {message_data}")
    old_balance_0 = token.balanceOf(accounts[0])
    old_balance_1 = token.balanceOf(accounts[1])
    # Perform the transfer
    peniwallet.transfer(
        message_data['token'],
        message_data['from'],
        message_data['to'],
        message_data['amount'],
        message_data['nonce'],
        message_data['deadline'],
        signature,
        {'from': accounts[0]}
    )

    # Check that the transfer was successful
    print("token.balanceOf(accounts[1]):", token.balanceOf(accounts[1]))
    print("token.balanceOf(accounts[0]):", token.balanceOf(accounts[0]))
    assert token.balanceOf(accounts[0]) == old_balance_0 - 500
    assert token.balanceOf(accounts[1]) > old_balance_1

def test_transfer_expired(peniwallet, token, accounts):
    
    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, 1000, {'from': accounts[0]})

    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts)
    message_data['deadline'] = chain.time() - 3600

    # Attempt to perform the transfer
    with pytest.raises(ValueError):
        peniwallet.transfer(
            message_data['token'],
            message_data['from'],
            message_data['to'],
            message_data['amount'],
            message_data['nonce'],
            message_data['deadline'],
            signature,
            {'from': accounts[0]}
        )

def test_transfer_invalid_signature(peniwallet, token, accounts):

    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, 1000, {'from': accounts[0]})

    # Generate an invalid signature for the transfer
    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts)
    signature = signature[:-1] + '0'
    
    # Attempt to perform the transfer
    with pytest.raises(ValueError):
        peniwallet.transfer(
            message_data['token'],
            message_data['from'],
            message_data['to'],
            message_data['amount'],
            message_data['nonce'],
            message_data['deadline'],
            signature,
            {'from': accounts[0]}
        )

def test_admin_added_event(peniwallet, accounts):
    # Add an admin
    tx = peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Check that the AdminAdded event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['admin'] == accounts[1]
    assert tx.events[0]['addedBy'] == accounts[0]

def test_admin_removed_event(peniwallet, accounts):
    # Add an admin
    peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Remove the admin
    tx = peniwallet.removeAdmin(accounts[1], {'from': accounts[0]})

    # Check that the AdminRemoved event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['admin'] == accounts[1]
    assert tx.events[0]['removedBy'] == accounts[0]

def test_min_fee_set_event(peniwallet, accounts):
    # Set the minimum fee
    tx = peniwallet.setMinFee(100, {'from': accounts[0]})

    # Check that the MinFeeSet event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['minFee'] == 100
    assert tx.events[0]['setBy'] == accounts[0]

def test_fee_multiplier_set_event(peniwallet, accounts):
    # Set the fee multiplier
    tx = peniwallet.setFeeMultiplier(1, 2, {'from': accounts[0]})

    # Check that the FeeMultiplierSet event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['feeMultiplier'] == 2
    assert tx.events[0]['transactionType'] == 1
    assert tx.events[0]['setBy'] == accounts[0]

def test_gas_sent_event(peniwallet, accounts):
    # Send gas to a user
    tx = peniwallet.sendGas(accounts[1], {'from': accounts[0], 'value': 100})

    # Check that the GasSent event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['amount'] == 100
    assert tx.events[0]['sender'] == accounts[0]
    assert tx.events[0]['receiver'] == accounts[1]

def test_swapBNBForTokens(peniwallet, token, accounts):
    
    old_bnb_balance = accounts[0].balance()
    old_token_balance = token.balanceOf(accounts[0])

    # Swap BNB for tokens
    peniwallet.swapBNBForTokens(
        token.address,
        {'from': accounts[0], 'value': web3.toWei(0.003, 'ether')}
    )

    # Check that the swap was successful
    print(token.balanceOf(accounts[0]))
    assert accounts[0].balance() < old_bnb_balance
    assert token.balanceOf(accounts[0]) > old_token_balance

def test_swapTokensForBNB(peniwallet, token, accounts):
    # Approve the Peniwallet contract to spend the sender's tokens
    amount = web3.toWei(1000000, 'ether')
    token.approve(peniwallet.address, amount, {'from': accounts[0]})

    # Generate a signature for the transfer
    signature, message_data = prepare_swap_data(peniwallet.address, token.address, accounts, amount=amount)
    print(signature)
    print(message_data)
    old_token_balance = token.balanceOf(accounts[0])
    old_bnb_balance = accounts[0].balance()
    # Perform the transfer
    peniwallet.swapTokensForBNB(
        message_data['tokenA'],
        message_data['from'],
        message_data['amountA'],
        message_data['nonce'],
        message_data['deadline'],
        signature,
        {'from': accounts[0]}
    )

    # Check that the transfer was successful
    print(f"old_token_balance: {old_token_balance}")
    print(f"old_bnb_balance: {old_bnb_balance}")

    print(f"new_token_balance: {token.balanceOf(accounts[0])}")
    print(f"new_bnb_balance: {accounts[0].balance()}")


    assert token.balanceOf(accounts[0]) < old_token_balance
    assert accounts[0].balance() != old_bnb_balance

def test_calculate_fees(peniwallet, accounts):
    # Calculate the fees for a transfer
    fees = peniwallet.estimateFees(100, 1, {'from': accounts[0]})

    # Check that the fees were calculated correctly
    assert fees == 2