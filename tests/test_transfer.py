
from eth_account import Account
import pytest
from brownie import chain, web3
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_structured_data
from eth_account.signers.local import LocalAccount


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

    account: LocalAccount = Account.from_key("0x77f9759818d266f09c7f96dac8d7e6af15f66858180f06f11caaea2ee627efc0")
    encoded_message = encode_structured_data(message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data


def test_transfer(peniwallet, token, accounts):

    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, token.totalSupply(), {'from': accounts[0]})
    amount = web3.toWei(100000, 'ether')
    # Generate a signature for the transfer
    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts, amount=amount)
    print(f"signature: {signature}")
    print(f"message_data: {message_data}")
    old_balance_0 = token.balanceOf(accounts[0])
    old_balance_1 = token.balanceOf(accounts[1])

    print(f"old_balance_0: {old_balance_0}")
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
    assert token.balanceOf(accounts[0]) < old_balance_0
    assert token.balanceOf(accounts[1]) > old_balance_1

def test_transfer_expired(peniwallet, token, accounts):
    
    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, 1000, {'from': accounts[0]})

    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts)
    message_data['deadline'] = chain.time() - 3600

    # Attempt to perform the transfer
    with pytest.raises(ValueError) as exc:
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
        assert "expired" in str(exc.value)

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
