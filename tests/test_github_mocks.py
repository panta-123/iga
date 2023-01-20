import iga.github
from iga.github import GitHubRelease, GitHubRepo, GitHubUser
from os import path
import json5

HERE = path.dirname(path.abspath(__file__))


def test_mocking_release(mocker):
    release_file = path.join(HERE, 'data', 'github-examples', 'with-codemeta',
                             'cds-astro', 'tutorials', 'release.json')
    with open(release_file, 'r') as f:
        release_json = json5.load(f)

    mocked_function = mocker.patch("iga.github._object_for_github")
    mocked_function.return_value = GitHubRelease(release_json)
    value = mocked_function()
    assert isinstance(value, GitHubRelease)
    assert value.id == 89397362
    assert value.author.login == 'ManonMarchand'


def test_mocking_repo(mocker):
    repo_file = path.join(HERE, 'data', 'github-examples', 'with-codemeta',
                          'cds-astro', 'tutorials', 'repo.json')
    with open(repo_file, 'r') as f:
        repo_json = json5.load(f)

    mocked_function = mocker.patch("iga.github._object_for_github")
    mocked_function.return_value = GitHubRepo(repo_json)
    value = mocked_function()
    assert isinstance(value, GitHubRepo)
    assert value.name == 'tutorials'
    assert value.owner.login == 'cds-astro'
    assert value.subscribers_count == 10


def test_mocking_user(mocker):
    user_file = path.join(HERE, 'data', 'github-examples', 'with-codemeta',
                          'datacite', 'akita', 'user.json')
    with open(user_file, 'r') as f:
        user_json = json5.load(f)

    mocked_function = mocker.patch("iga.github._object_for_github")
    mocked_function.return_value = GitHubUser(user_json)
    value = mocked_function()
    assert isinstance(value, GitHubUser)
    assert value.url == 'https://api.github.com/users/digitaldogsbody'


def test_mocking_repo_file(mocker):
    codemeta_file = path.join(HERE, 'data', 'github-examples', 'with-codemeta',
                              'cds-astro', 'tutorials', 'codemeta.json')
    with open(codemeta_file, 'r') as f:
        codemeta_json = json5.load(f)

    mocked_function = mocker.patch("iga.github.github_repo_file")
    mocked_function.return_value = codemeta_json
    value = mocked_function('foo/repo', 'codemeta.json')
    assert isinstance(value, dict)
    assert value['codeRepository'] == 'git+https://github.com/cds-astro/tutorials'
