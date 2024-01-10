from eth_account import Account
import pytest
from brownie import Peniwallet, chain, web3, BEP20XRP, config, network
from brownie import accounts as _accounts
from eth_account.datastructures import SignedMessage
from eth_account.messages import encode_structured_data
from eth_account.signers.local import LocalAccount

@pytest.fixture(scope="module")
def accounts():
    if network.show_active() != "localnet":
        _accounts.add(config["wallets"]["account-0"])
        _accounts.add(config["wallets"]["account-1"])
        _accounts.add(config["wallets"]["account-2"])
    return _accounts


@pytest.fixture(scope="module")
def peniwallet(accounts):
    
    return Peniwallet[-1] if Peniwallet else Peniwallet.deploy(
        1700,
        2000,
        5000,
        100,
        "0x7D23030D967d26462966Fa8E6968EADe0F7a2361",
        "0x527A39f480dE9126d48B1B23215Bf8C0a784F447",
        {'from': accounts[0]})

@pytest.fixture(scope="module")
def token(accounts):

    return BEP20XRP.at("0xD309CD40E0fC4c463a28bAd37b644705220cE348")
