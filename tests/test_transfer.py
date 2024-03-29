
from eth_account import Account
import pytest
from ape import chain
from web3 import Web3
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_typed_data
from eth_account.signers.local import LocalAccount


def prepare_transfer_data(contract, token, accounts, nonce, amount = 500):
    message_data = {
        'token': token,
        'from': accounts[1].address,
        'to': accounts[0].address,
        'amount': amount,
        'nonce': nonce,
        'deadline': chain.pending_timestamp + 3600
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
            'chainId': chain.chain_id,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': contract,
        }
    }

    account: LocalAccount = Account.from_key("0x4417c04ddfd88b3fdaaffba80ce8e071da0e0137c55efb81c2beb1c0cc1d33b8")
    encoded_message = encode_typed_data(full_message=message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data


def test_transfer(peniwallet, token, accounts):

    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, token.totalSupply(), sender = accounts[1])
    amount = Web3.to_wei(100000, 'ether')

    # get nonce
    nonce = peniwallet.getNonce(accounts[1].address)
    print(f"nonce: {nonce} for address: {accounts[1].address}")

    # Generate a signature for the transfer
    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts, nonce, amount=amount)
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
        21000,
        sender = accounts[1]
    )

    # Check that the transfer was successful
    print("token.balanceOf(accounts[0]):", token.balanceOf(accounts[0]))
    print("token.balanceOf(accounts[1]):", token.balanceOf(accounts[1]))
    assert token.balanceOf(accounts[1]) < old_balance_1
    assert token.balanceOf(accounts[0]) > old_balance_0

def test_transfer_expired(peniwallet, token, accounts):
    
    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, 1000, sender = accounts[0])

    # get nonce
    nonce = peniwallet.getNonce(accounts[0].address)

    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts, nonce)
    message_data['deadline'] = chain.pending_timestamp - 3600

    # Attempt to perform the transfer
    with pytest.raises(Exception) as exc:
        peniwallet.transfer(
            message_data['token'],
            message_data['from'],
            message_data['to'],
            message_data['amount'],
            message_data['nonce'],
            message_data['deadline'],
            signature,
            21000,
            sender = accounts[0]
        )
        assert "expired" in str(exc.value)

def test_transfer_invalid_signature(peniwallet, token, accounts):

    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, 1000, sender = accounts[0])

    # get nonce
    nonce = peniwallet.getNonce(accounts[0].address)

    # Generate an invalid signature for the transfer
    signature, message_data = prepare_transfer_data(peniwallet.address, token.address, accounts, nonce)
    signature = signature[:-1] + '0'
    
    # Attempt to perform the transfer
    with pytest.raises(Exception) as error:
        peniwallet.transfer(
            message_data['token'],
            message_data['from'],
            message_data['to'],
            message_data['amount'],
            message_data['nonce'],
            message_data['deadline'],
            signature,
            21000,
            sender = accounts[0]
        )

    assert "Invalid signature" in str(error.value)
