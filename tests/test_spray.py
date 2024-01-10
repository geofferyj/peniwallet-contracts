from web3 import Web3
from brownie import chain
from eth_account import Account
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_structured_data
from eth_account.signers.local import LocalAccount


# struct SprayTransaction {
#         address token;
#         address from;
#         address[] receivers;
#         uint256 amount;
#         uint256 nonce;
#         uint256 deadline;
#     }

def prepare_swap_data(contract, token, accounts, receivers, amount=500):
    message_data = {
        'token': token,
        'from': accounts[0].address,
        'receivers': receivers,
        'amount': amount,
        'nonce': 0,
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
            'SprayTransaction': [
                {'name': 'token', 'type': 'address'},
                {'name': 'from', 'type': 'address'},
                {'name': 'receivers', 'type': 'address[]'},
                {'name': 'amount', 'type': 'uint256'},
                {'name': 'nonce', 'type': 'uint256'},
                {'name': 'deadline', 'type': 'uint256'},
            ],
        },
        'message': message_data,
        'primaryType': 'SprayTransaction',
        'domain': {
            'name': 'Peniwallet',
            'version': '1',
            'chainId': chain.id,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': contract,
        }
    }

    # account: LocalAccount = Account.from_key(accounts[0].private_key)
    account: LocalAccount = Account.from_key(
        "0x77f9759818d266f09c7f96dac8d7e6af15f66858180f06f11caaea2ee627efc0")

    encoded_message = encode_structured_data(message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data




def test_spray_token(peniwallet, token, accounts):
    # Approve the Peniwallet contract to spend the sender's tokens
    amount = Web3.toWei(1000000, 'ether')
    token.approve(peniwallet.address, amount, {'from': accounts[0]})

    # Generate a signature for the transfer
    signature, message_data = prepare_spray_data(
        peniwallet.address, token.address, accounts, amount=amount)
    print(signature)
    print(message_data)
    old_token_balance = token.balanceOf(accounts[0])

    # Perform the transfer
    peniwallet.sprayToken(
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

    print(f"new_token_balance: {token.balanceOf(accounts[0])}")

    assert token.balanceOf(accounts[0]) < old_token_balance
