from eth_account import Account
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_structured_data
from eth_account.signers.local import (
    LocalAccount,
)
def test_verifier():

    account: LocalAccount = Account.from_key(
        '0x110854350f206b75d3824dd19cefdde5f1e6359c3e3bab5b62f8b21541aa6fa2',
        )
    # Define the EIP-712 data for the permit
    message_data = {
        'from': account.address,
        'to': '0xFf9AF912c35273A7d84ba9271e016d57a0AA1B29',
        'value': 100,  # Amount of tokens to approve
        'nonce': 0,    # Replace with the nonce value from the contract
        'deadline': 0,  # Replace with the expiration timestamp
    }

    # Construct the EIP-712 message
    message = {
        'types': {
            'EIP712Domain': [
                {'name': 'name', 'type': 'string'},
                {'name': 'version', 'type': 'string'},
                {'name': 'chainId', 'type': 'uint256'},
                {'name': 'verifyingContract', 'type': 'address'},
            ],
            'Transaction': [
                {'name': 'from', 'type': 'address'},
                {'name': 'to', 'type': 'address'},
                {'name': 'value', 'type': 'uint256'},
                {'name': 'nonce', 'type': 'uint256'},
                {'name': 'deadline', 'type': 'uint256'},
            ],
        },
        'message': message_data,
        'primaryType': 'Transaction',
        'domain': {
            'name': 'EIP712Verifier',
            'version': '1',
            'chainId': 1337,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': '0x6d8F2b7286777Fd28ff2A111CA1E4AF6991Db943',
        }
    }

    # Encode the EIP-712 message
    encoded_message = encode_structured_data(message)

    print("encoded_message",encoded_message)

    print("Account Address:", account.address)


    # Sign the encoded message
    signature: SignedMessage = account.sign_message(encoded_message)

    print('Permit Signature:', signature.signature.hex())

