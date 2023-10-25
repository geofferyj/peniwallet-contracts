def test_add_admin(peniwallet, accounts):
    # Add an admin
    peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Check that the admin was added
    assert peniwallet.admins(accounts[1]) == True

def test_remove_admin(peniwallet, accounts):
    # Add an admin
    peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Remove the admin
    peniwallet.removeAdmin(accounts[1], {'from': accounts[0]})

    # Check that the admin was removed
    assert peniwallet.admins(accounts[1]) == False

def test_admin_added_event(peniwallet, accounts):
    # Add an admin
    tx = peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Check that the AdminAdded event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['admin'] == accounts[1]
    assert tx.events[0]['addedBy'] == accounts[0]

def test_admin_removed_event(peniwallet, accounts):
    # Add an admin
    peniwallet.addAdmin(accounts[1], {'from': accounts[0]})

    # Remove the admin
    tx = peniwallet.removeAdmin(accounts[1], {'from': accounts[0]})

    # Check that the AdminRemoved event was emitted
    assert len(tx.events) == 1
    assert tx.events[0]['admin'] == accounts[1]
    assert tx.events[0]['removedBy'] == accounts[0]
