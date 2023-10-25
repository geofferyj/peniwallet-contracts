
import web3


def test_set_min_fee(peniwallet, accounts):
    # Set the minimum fee
    peniwallet.setMinFee(100, {'from': accounts[0]})

    # Check that the minimum fee was set
    assert peniwallet.minFee() == 100

def test_set_fee_multiplier(peniwallet, accounts):
    # Set the fee multiplier
    peniwallet.setFeeMultiplier(1, 3000, {'from': accounts[0]})

    # Check that the fee multiplier was set
    assert peniwallet.feeMultiplier(1) == 3000

def test_set_dev_fee_share(peniwallet, accounts):
    # Set the dev fee share
    peniwallet.setDevFeeShare(50, {'from': accounts[0]})

    # Check that the dev fee share was set
    assert peniwallet.devFeeShare() == 50

def test_register_project(peniwallet, accounts, token):
    # Register a project
    peniwallet.registerProject(accounts[1], token.address, {'from': accounts[0]})

    # Check that the project was registered
    assert peniwallet.projects(token.address) == accounts[1].address
    print("getFeeByAddress", peniwallet.getFeeByAddress(accounts[1].address, token.address))



def test_min_fee_set_event(peniwallet, accounts):
    # Set the minimum fee
    tx = peniwallet.setMinFee(100, {'from': accounts[0]})

    # Check that the MinFeeSet event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['minFee'] == 100
    assert tx.events[0]['setBy'] == accounts[0]

def test_fee_multiplier_set_event(peniwallet, accounts):
    # Set the fee multiplier
    tx = peniwallet.setFeeMultiplier(1, 2, {'from': accounts[0]})

    # Check that the FeeMultiplierSet event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['feeMultiplier'] == 2
    assert tx.events[0]['transactionType'] == 1
    assert tx.events[0]['setBy'] == accounts[0]

def test_calculate_fees(peniwallet, accounts, token):
    # Calculate the fees for a transfer
    fees = peniwallet.estimateFees(token.address, web3.Web3.toWei(100000, "ether"), 0, {'from': accounts[0]})
    assert web3.Web3.fromWei(fees, "ether") == 1700
    