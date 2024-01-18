from ape import accounts
from ape.project import EIP712Verifier


def deploy_verifier():
    return EIP712Verifier.deploy(sender=accounts[0])
