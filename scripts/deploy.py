from brownie import EIP712Verifier, accounts


def deploy_verifier():
    return EIP712Verifier.deploy({'from': accounts[0]})
