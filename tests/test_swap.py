from web3 import Web3
from eth_account import Account
from ape import chain
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_typed_data
from eth_account.signers.local import LocalAccount


def prepare_swap_data(contract, token_a, token_b, accounts, nonce, amount=500):
    message_data = {
        'tokenA': token_a,
        'tokenB': token_b,
        'from': accounts[0].address,
        'amountA': amount,
        'amountB': amount,
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
            'chainId': chain.chain_id,  # Binance Smart Chain (BSC) chain ID
            'verifyingContract': contract,
        }
    }

    # account: LocalAccount = Account.from_key(accounts[0].private_key)
    account: LocalAccount = Account.from_key(
        "0x77f9759818d266f09c7f96dac8d7e6af15f66858180f06f11caaea2ee627efc0")

    encoded_message = encode_typed_data(full_message=message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data


def test_swapBNBForTokens(peniwallet, token, accounts):

    old_bnb_balance = accounts[0].balance
    old_token_balance = token.balanceOf(accounts[0])

    # Swap BNB for tokens
    peniwallet.swapBNBForTokens(
        token.address,
        sender = accounts[0],
        value =  Web3.to_wei(0.003, 'ether')
    )

    # Check that the swap was successful
    print(token.balanceOf(accounts[0]))
    assert accounts[0].balance < old_bnb_balance
    assert token.balanceOf(accounts[0]) > old_token_balance


def test_swapTokensForBNB(peniwallet, token, accounts):
    # Approve the Peniwallet contract to spend the sender's tokens
    amount = Web3.to_wei(1000000, 'ether')

    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, token.totalSupply(), sender = accounts[0])

    # get nonce
    nonce = peniwallet.getNonce(accounts[0].address)
    print(f"nonce: {nonce} for address: {accounts[0].address}")

    # Generate a signature for the swap
    signature, message_data = prepare_swap_data(
        peniwallet.address,
        token.address,
        "0xf7e22e248481eb6905ba1e06c1d3f06f819d50df",
        accounts,
        nonce,
        amount=amount,
    )

    old_token_balance = token.balanceOf(accounts[0])
    old_bnb_balance = accounts[0].balance
    # Perform the swap
    peniwallet.swapTokensForBNB(
        [message_data['tokenA'], "0xf7E22E248481eb6905Ba1e06c1d3F06f819D50df"],
        message_data['from'],
        message_data['amountA'],
        message_data['nonce'],
        message_data['deadline'],
        signature,
        21000,
        sender = accounts[0]
    )

    # Check that the transfer was successful
    print(f"old_token_balance: {old_token_balance}")
    print(f"old_bnb_balance: {old_bnb_balance}")

    print(f"new_token_balance: {token.balanceOf(accounts[0])}")
    print(f"new_bnb_balance: {accounts[0].balance}")

    assert token.balanceOf(accounts[0]) < old_token_balance
    assert accounts[0].balance != old_bnb_balance


def test_swapTokensForTokens(peniwallet, token, accounts):
    # Approve the Peniwallet contract to spend the sender's tokens
    amount = Web3.to_wei(1000000, 'ether')
    
    # Approve the Peniwallet contract to spend the sender's tokens
    token.approve(peniwallet.address, token.totalSupply(), sender = accounts[0])

    token_out = "0x527A39f480dE9126d48B1B23215Bf8C0a784F447"
    bnb = "0xf7E22E248481eb6905Ba1e06c1d3F06f819D50df"

    # get nonce
    nonce = peniwallet.getNonce(accounts[0].address)
    print(f"nonce: {nonce} for address: {accounts[0].address}")

    # Generate a signature for the transfer
    signature, message_data = prepare_swap_data(
        peniwallet.address,
        token.address,
        token_out,
        accounts,
        nonce,
        amount=amount,
    )

    old_tokenIn_balance = token.balanceOf(accounts[0])

    # Perform the swap
    peniwallet.swapTokensForTokens(
        [message_data['tokenA'], bnb, message_data['tokenB']],
        message_data['from'],
        message_data['amountA'],
        message_data['nonce'],
        message_data['deadline'],
        signature,
        21000,
        sender = accounts[0]
    )

    # Check that the transfer was successful
    print(f"old_tokenIn_balance: {old_tokenIn_balance}")

    print(f"new_tokenIn_balance: {token.balanceOf(accounts[0])}")

    assert token.balanceOf(accounts[0]) < old_tokenIn_balance
