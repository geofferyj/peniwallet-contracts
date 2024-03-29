import pytest
# from ape import project, accounts


@pytest.fixture(scope="session")
def peniwallet(project, accounts):
    print("deployments", project.Peniwallet.deployments)
    return project.Peniwallet.at("0x6A91E1CCB510B6559ddE852EBcC9c8A2406373b8")
# .deploy(
#         1700, 
#         2000,
#         5000,
#         "0x7D23030D967d26462966Fa8E6968EADe0F7a2361",
#         "0x527A39f480dE9126d48B1B23215Bf8C0a784F447",
#         sender=accounts[0])

@pytest.fixture(scope="module")
def token(project):

    return project.BEP20XRP.at("0xD309CD40E0fC4c463a28bAd37b644705220cE348")


@pytest.fixture(scope="module")
def addresses():
    """
    Fixture function that returns a list of addresses read from a file.
    """
    with open("tests/addresses.txt", encoding="utf8") as file:
        _addresses = file.readlines()
    return [add.strip() for add in _addresses]
