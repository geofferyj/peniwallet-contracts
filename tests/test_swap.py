from eth_account import Account
from brownie import chain, web3
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_structured_data
from eth_account.signers.local import LocalAccount


def prepare_swap_data(contract, token_a, token_b, accounts, amount=500):
    message_data = {
        'tokenA': token_a,
        'tokenB': token_b,
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

    # account: LocalAccount = Account.from_key(accounts[0].private_key)
    account: LocalAccount = Account.from_key(
        "0x77f9759818d266f09c7f96dac8d7e6af15f66858180f06f11caaea2ee627efc0")

    encoded_message = encode_structured_data(message)
    signature: SignedMessage = account.sign_message(encoded_message)
    return signature.signature.hex(), message_data


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

    # Generate a signature for the swap
    signature, message_data = prepare_swap_data(
        peniwallet.address, token.address, "0xf7e22e248481eb6905ba1e06c1d3f06f819d50df", accounts, amount=amount)

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


def test_swapTokensForTokens(peniwallet, token, accounts):
    # Approve the Peniwallet contract to spend the sender's tokens
    amount = web3.toWei(1000000, 'ether')
    token.approve(peniwallet.address, amount, {'from': accounts[0]})

    token_out = "0x527A39f480dE9126d48B1B23215Bf8C0a784F447"
    bnb = "0xf7E22E248481eb6905Ba1e06c1d3F06f819D50df"

    # Generate a signature for the transfer
    signature, message_data = prepare_swap_data(
        peniwallet.address, token.address, token_out, accounts, amount=amount)
    print(signature)
    print(message_data)
    old_tokenIn_balance = token.balanceOf(accounts[0])

    # Perform the swap
    peniwallet.swapTokensForTokens(
        [message_data['tokenA'], bnb, message_data['tokenB']],
        message_data['from'],
        message_data['amountA'],
        message_data['nonce'],
        message_data['deadline'],
        signature,
        {'from': accounts[0]}
    )

    # Check that the transfer was successful
    print(f"old_tokenIn_balance: {old_tokenIn_balance}")


    print(f"new_tokenIn_balance: {token.balanceOf(accounts[0])}")


    assert token.balanceOf(accounts[0]) < old_tokenIn_balance
