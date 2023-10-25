from eth_account import Account
import pytest
from brownie import Peniwallet, chain, web3, ERC20Mock, config, network
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
    return Peniwallet.deploy(1700, 2000, 5000, 100, {'from': accounts[0]})
    # return Peniwallet.at('0x85eaAc08bd9203f42715527CC4258cE759F4C243')
    # return Peniwallet.at('0x3D1c49B450D5256255524eD1065A52ABc7256070')

@pytest.fixture(scope="module")
def token(accounts):
    # USDT
    # return ERC20Mock.at('0x55d398326f99059fF775485246999027B3197955')

    # WKC
    # return ERC20Mock.at('0x6ec90334d89dbdc89e08a133271be3d104128edb')

    return ERC20Mock.deploy({'from': accounts[0]})
