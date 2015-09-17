TreeViewGitStatus = require '../lib/main'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "TreeViewGitStatus", ->
  [workspaceElement, gitStatus, treeView, fixturesPath] = []

  beforeEach ->
    fixturesPath = atom.project.getPaths()[0]
    atom.project.removePath(fixturesPath)

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    waitsForPromise ->
      atom.packages.activatePackage('tree-view-git-status').then (pkg) ->
        gitStatus = pkg.mainModule
        treeView = gitStatus.treeView
        # TODO Remove enforcing trailing slashes... currently
        # repo path comparison will fail on Windows all paths
        # are containing trailing slashes but the fixtures path
        # contains backslashes...
        gitStatus.ignoreRepository(
          (path.resolve(fixturesPath, '..','..').split path.sep).join('/'))

  afterEach ->
    temp.cleanup()

  it 'activates the TreeViewGitStatus package', ->
    expect(gitStatus).toBeDefined()
    expect(gitStatus.treeView).toBeDefined()

  it 'adds valid Git repositories to the repository map', ->
    projPaths = [extractGitRepoFixture(fixturesPath, 'git-project')]
    atom.project.setPaths(projPaths)
    validateProjectPaths projPaths

    expect(gitStatus.toggled).toBe(true)
    expect(atom.project.getRepositories().length).toBe(1)
    expect(gitStatus.repositoryMap.size).toBe(1)

  it 'disables the TreeViewGitStatus when toggled', ->
    projPaths = [extractGitRepoFixture(fixturesPath, 'git-project')]
    atom.project.setPaths(projPaths)
    validateProjectPaths projPaths

    expect(gitStatus.toggled).toBe(true)
    expect(gitStatus.repositoryMap.size).toBe(1)

    for root in treeView.roots
      rootPath = gitStatus.normalizePath root.directoryName.dataset.path
      # Makes debugging easier if we also compare the keys directly
      expect(gitStatus.repositoryMap.keys().next().value).toBe(rootPath)
      expect(gitStatus.repositoryMap.has(rootPath)).toBe(true)
      expect(root.header.querySelector('span.tree-view-git-status')).toExist()

    gitStatus.toggle()

    for root in treeView.roots
      expect(root.header.querySelector('span.tree-view-git-status'))
        .not.toExist()

    expect(gitStatus.toggled).toBe(false)
    expect(gitStatus.subscriptions.disposed).toBe(true)
    expect(gitStatus.repositorySubscriptions.disposed).toBe(true)
    expect(gitStatus.repositoryMap.size).toBe(0)
    expect(gitStatus.ignoredRepositories.size).not.toBeNull()

  it 'skips adding the TreeViewGitStatus on none Git projects', ->
    projPaths = [path.join(fixturesPath, 'none-git-project')]
    atom.project.setPaths(projPaths)
    validateProjectPaths projPaths

    expect(gitStatus.toggled).toBe(true)
    # TODO For some reason the atom-tree-view-git-status GitRepo gets added
    # expect(atom.project.getRepositories().length).toBe(0)

    for root in treeView.roots
      expect(root.header.querySelector('span.tree-view-git-status'))
        .not.toExist()

  describe 'when deactivated', ->
    beforeEach ->
      projPaths = [extractGitRepoFixture(fixturesPath, 'git-project')]
      atom.project.setPaths(projPaths)
      validateProjectPaths projPaths

      expect(gitStatus.toggled).toBe(true)
      expect(atom.project.getRepositories().length).toBe(1)

      runs ->
        gitStatus.deactivate()

    it 'destroys the TreeViewGitStatus instance', ->
      expect(gitStatus.active).toBe(false)
      expect(gitStatus.toggled).toBe(false)
      expect(gitStatus.subscriptions).toBeNull()
      expect(gitStatus.treeView).toBeNull()
      expect(gitStatus.repositorySubscriptions).toBeNull()
      expect(gitStatus.treeViewRootsMap).toBeNull()
      expect(gitStatus.repositoryMap).toBeNull()
      expect(gitStatus.ignoredRepositories).toBeNull()

    it 'destroys the Git Status elements that were added to the DOM', ->
      for root in treeView.roots
        expect(root.header.querySelector('span.tree-view-git-status'))
          .not.toExist()

  extractGitRepoFixture = (fixturesPath, dotGitFixture) ->
    dotGitFixturePath = path.join(fixturesPath, dotGitFixture, 'git.git')
    dotGit = path.join(temp.mkdirSync('repo'), '.git')
    fs.copySync(dotGitFixturePath, dotGit)
    return path.resolve dotGit, '..'

  validateProjectPaths = (projPaths) ->
    expect(atom.project.getPaths().length).toBe(projPaths.length)
    for pPath in atom.project.getPaths()
      expect(projPaths.indexOf pPath).toBeGreaterThan(-1)
    expect(treeView.roots.length).toBe(projPaths.length)
