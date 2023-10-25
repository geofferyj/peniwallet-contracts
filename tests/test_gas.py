
def test_send_gas(peniwallet, accounts):

    old_balance = accounts[1].balance()
    # Send gas to a user
    peniwallet.sendGas(accounts[1], {'from': accounts[0], 'value': 10})

    # Check that the gas was sent
    assert accounts[1].balance() == old_balance + 10


def test_gas_sent_event(peniwallet, accounts):
    # Send gas to a user
    tx = peniwallet.sendGas(accounts[1], {'from': accounts[0], 'value': 100})

    # Check that the GasSent event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['amount'] == 100
    assert tx.events[0]['sender'] == accounts[0]
    assert tx.events[0]['receiver'] == accounts[1]
