import pytest
from web3 import Web3
from ape import chain
from eth_account import Account
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_typed_data
from eth_account.signers.local import LocalAccount


def prepare_spray_data(contract, token, accounts, receivers, amount=500, code="NWBx76"):

    message_data = {
        'token': token,
        'from': accounts[0].address,
        'receivers': receivers,
        'amount': amount,
        'code': code
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
                {'name': 'code', 'type': 'string'},
            ],
        },
        'message': message_data,
        'primaryType': 'SprayTransaction',
        'domain': {
            'name': 'Peniwallet',
            'version': '1',
            'chainId': chain.chain_id,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': contract,
        }
    }

    account: LocalAccount = Account.from_key("0x77f9759818d266f09c7f96dac8d7e6af15f66858180f06f11caaea2ee627efc0")
    encoded_message = encode_typed_data(full_message=message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data



# def test_spray_token(peniwallet, token, accounts, addresses):

#     receivers = addresses[:200]
#     amount = Web3.to_wei(1, 'ether')
#     token.approve(peniwallet.address, token.totalSupply(), sender = accounts[1])

#     # Generate a signature for the transfer
#     signature, message_data = prepare_spray_data(
#         peniwallet.address, token.address, accounts, receivers, amount=amount)
    
#     print("signature", signature)

#     old_token_balances = [token.balanceOf(address) for address in receivers]

#     # Perform the transfer
#     peniwallet.sprayToken(
#         message_data['token'],
#         message_data['from'],
#         message_data['receivers'],
#         message_data['amount'],
#         "mega spray",
#         message_data['code'],
#         signature,
#         21000,
#         sender = accounts[1]
#     )

#     # Check that the transfer was successful
#     new_token_balances = [token.balanceOf(address) for address in receivers]

#     assert all(
#         new_token_balances[i] == old_token_balances[i] + amount for i in range(len(receivers)))



# def test_spray_token_duplicate(peniwallet, token, accounts, addresses):

#     receivers = addresses[:10]
#     amount = Web3.to_wei(1, 'ether')
#     token.approve(peniwallet.address, token.totalSupply(), sender = accounts[1])

#     # Generate a signature for the transfer
#     signature, message_data = prepare_spray_data(
#         peniwallet.address, token.address, accounts, receivers, amount=amount)
    
#     print("signature", signature)

#     # Perform the spray
#     peniwallet.sprayToken(
#         message_data['token'],
#         message_data['from'],
#         message_data['receivers'],
#         message_data['amount'],
#         "mega spray",
#         message_data['code'],
#         signature,
#         21000,
#         sender = accounts[1]
#     )

#     with pytest.raises(Exception) as exc:
#         peniwallet.sprayToken(
#         message_data['token'],
#         message_data['from'],
#         message_data['receivers'],
#         message_data['amount'],
#         "mega spray",
#         message_data['code'],
#         signature,
#         21000,
#         sender = accounts[1]
#         )

#         assert "Spray already executed" in str(exc.value)


# def test_spray_estimate_gas(peniwallet, token, accounts, addresses):

#     receivers = addresses[:10]
#     amount = Web3.to_wei(1, 'ether')
#     token.approve(peniwallet.address, token.totalSupply(), sender = accounts[1])

#     # Generate a signature for the transfer
#     signature, message_data = prepare_spray_data(
#         peniwallet.address, token.address, accounts, receivers, amount=amount)
    
#     print("signature", signature)

#     # Perform the spray
#     peniwallet.sprayToken(
#         message_data['token'],
#         message_data['from'],
#         message_data['receivers'],
#         message_data['amount'],
#         "mega spray",
#         message_data['code'],
#         signature,
#         21000,
#         sender = accounts[1]
#     )

#     with pytest.raises(Exception) as exc:
#         peniwallet.sprayToken(
#         message_data['token'],
#         message_data['from'],
#         message_data['receivers'],
#         message_data['amount'],
#         "mega spray",
#         message_data['code'],
#         signature,
#         21000,
#         sender = accounts[1]
#         )

#         assert "Spray already executed" in str(exc.value)

def test_get_fees(peniwallet, token, accounts, addresses):

    receivers = [
  "0x318e7611f411a6b61E55924E6D652ad5e5D4BF43",
  "0x318E7611f411a6B61e55924E6D652aD5e5D4Bf4E",
  "0x318e7611F411A6b61E55924e6D652ad5e5d4Bf4f",
  "0x58eC9587204FceA311E32BC7674a75443eB8f653",
  "0x318E7611F411A6b61e55924e6D652ad5E5D4BF45"
] #addresses[:200]
    amount = 10 #Web3.to_wei(1, 'ether')
    token.approve(peniwallet.address, token.totalSupply(), sender = accounts[0])

    # Generate a signature for the transfer
    signature, message_data = prepare_spray_data(
        peniwallet.address, token.address, accounts, receivers, amount=amount, code="MBASYW")
    
    print("signature", signature)
    print("message_data", message_data)

    old_token_balances = [token.balanceOf(address) for address in receivers]


    # Check that the transfer was successful
    new_token_balances = [token.balanceOf(address) for address in receivers]

    assert all(
        new_token_balances[i] == old_token_balances[i] for i in range(len(receivers)))

