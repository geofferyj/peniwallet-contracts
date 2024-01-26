from ape import accounts
from ape import project


# def deploy_verifier():
#     return project.EIP712Verifier.deploy(sender=accounts[0])


def deploy_peniwallet():
    return project.Peniwallet.deploy(
        1700,
        2000,
        5000,
        "0x7D23030D967d26462966Fa8E6968EADe0F7a2361",
        "0x527A39f480dE9126d48B1B23215Bf8C0a784F447",
        sender=accounts[0])

def main():
    deploy_peniwallet()