
import web3


def test_set_fee_multiplier(peniwallet, accounts):
    # Set the fee multiplier
    peniwallet.setFeeMultiplier(1, 3000, sender = accounts[0])

    # Check that the fee multiplier was set
    assert peniwallet.feeMultiplier(1) == 3000

def test_set_dev_fee_share(peniwallet, accounts):
    # Set the dev fee share
    peniwallet.setDevFeeShare(50, sender = accounts[0])

    # Check that the dev fee share was set
    assert peniwallet.devFeeShare() == 50

def test_register_project(peniwallet, accounts, token):
    # Register a project
    peniwallet.registerProject(token.address, accounts[1], sender = accounts[0])

    # Check that the project was registered
    assert peniwallet.projects(token.address) == accounts[1].address
    print("getFeeByAddress", peniwallet.getFeeByAddress(accounts[1].address, token.address))

def test_fee_multiplier_set_event(peniwallet, accounts):
    # Set the fee multiplier
    tx = peniwallet.setFeeMultiplier(1, 2, sender = accounts[0])

    # Check that the FeeMultiplierSet event was emitted
    assert len(tx.events) == 1
    # assert tx.events[0].feeMultiplier == 2
    assert tx.events[0].transactionType == 1
    assert tx.events[0].setBy == accounts[0]

def test_calculate_fees(peniwallet, accounts, token):
    # Calculate the fees for a transfer

    # estimate initial gas for the transaction

    # pass initial fee to the function and tx type to the function

    fees = peniwallet.estimateFees(
        token.address, # token
        web3.Web3.to_wei(1000, "ether"), # amount
        0, # tx type
        21000, # initial gas
        sender = accounts[0],
        )

    print("fees", web3.Web3.from_wei(fees, "ether"))
    assert int(web3.Web3.from_wei(fees, "ether")) == 17
    