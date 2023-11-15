from web3 import Web3



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