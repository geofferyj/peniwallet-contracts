from eip712.messages import EIP712Message, EIP712Type
class TransferTransaction(EIP712Type):
    token: "address"
    from: "address"
    to: "address"
    amount: "uint256"
    nonce: "uint256"
    deadline: "uint256"

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

