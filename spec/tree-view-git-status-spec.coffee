TreeViewGitStatus = require '../lib/main'
utils = require '../lib/utils'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "TreeViewGitStatus", ->
  [workspaceElement, treeViewGitStatus, treeView,
    fixturesPath, unlockWaitFor, defaultDelay] = []

  beforeEach ->
    defaultDelay = 1000
    fixturesPath = atom.project.getPaths()[0]
    atom.project.removePath(fixturesPath)

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    # Wait unless the tree-view has been loaded an the
    # tree-view-git-status was toggled
    waitForPackageActivation('tree-view')
    waitForPackageActivation('tree-view-git-status', (pkg) ->
        return if pkg.mainModule.isActivated()
        waitsForPromise -> awaitCallback(pkg.mainModule,
          pkg.mainModule.onDidActivate)
      )

    runs ->
      treeViewGitStatus = atom.packages.getActivePackage('tree-view-git-status').mainModule
      # Use the getTreeView() to be safe due to different Atom versions
      treeView = treeViewGitStatus.getTreeView()

      # TODO Remove enforcing trailing slashes...
      # The repo path comparison will fail on Windows as all paths
      # are containing trailing slashes but the fixtures path
      # contains backslashes...
      treeViewGitStatus.ignoreRepository(
        (path.resolve(fixturesPath, '..','..').split path.sep).join('/'))

  afterEach ->
    temp.cleanup()

  it 'activates the TreeViewGitStatus package', ->
    expect(treeViewGitStatus).toBeDefined()
    expect(treeView).toBeDefined()

  it 'adds valid Git repositories', () ->
    # TODO Figure out why only this test triggers an
    # uncaught promise error: Repository has been destroyed(…)
    # error... NOTE: adding idle(defaultDelay) avoids this issue... but why?
    prepareProject('git-project')
    runs () ->
      expect(treeViewGitStatus.getRepositories()).not.toBeNull()
      expect(treeViewGitStatus.getRepositories().size).toBe(1)

  it 'disables the TreeViewGitStatus when toggled', ->
    prepareProject('git-project')
    # Wait until the git status has been injected into the tree-view...
    idle(defaultDelay)
    runs () ->
      repos = treeViewGitStatus.getRepositories()
      for root in treeView.roots
        rootPath = utils.normalizePath root.directoryName.dataset.path
        # Makes debugging easier if we compare the keys directly
        expect(repos.keys().next().value).toBe(rootPath)
        expect(repos.has(rootPath)).toBe(true)
        expect(root.header.querySelector('span.tree-view-git-status')).toExist()

      treeViewGitStatus.toggle()

      for root in treeView.roots
        expect(root.header.querySelector('span.tree-view-git-status'))
          .not.toExist()

      expect(treeViewGitStatus.toggled).toBe(false)
      expect(treeViewGitStatus.toggledSubscriptions).toBeNull()
      expect(treeViewGitStatus.repos).toBeNull()
      expect(treeViewGitStatus.treeViewUI).toBeNull()
      expect(treeViewGitStatus.ignoredRepositories.size).toBe(1)

  it 'skips adding the TreeViewGitStatus on none Git projects', ->
    prepareProject('none-git-project', true)
    # Wait until the git status has been injected into the tree-view...
    idle(defaultDelay)
    runs ->
      expect(treeViewGitStatus.toggled).toBe(true)
      # TODO For some reason the atom-tree-view-git-status GitRepo gets added
      # in case we add a none Git project to Atom...
      # Figure out why or file a bug...
      # expect(atom.project.getRepositories().length).toBe(0)
      expect(treeViewGitStatus.getRepositories()).not.toBeNull()
      expect(treeViewGitStatus.getRepositories().size).toBe(0)
      expect(treeView.roots.length).toBe(1)

      for root in treeView.roots
        expect(root.header.querySelector('span.tree-view-git-status'))
          .not.toExist()

  describe 'when deactivated', ->
    beforeEach ->
      prepareProject('git-project')
      # Wait until the git status has been injected into the tree-view...
      idle(defaultDelay)
      runs ->
        expect(treeViewGitStatus.toggled).toBe(true)
        expect(atom.project.getRepositories().length).toBe(1)
        expect(treeView.roots.length).toBe(1)
        treeViewGitStatus.deactivate()

    it 'destroys the TreeViewGitStatus instance', ->
      expect(treeViewGitStatus.active).toBe(false)
      expect(treeViewGitStatus.toggled).toBe(false)
      expect(treeViewGitStatus.subscriptions).toBeNull()
      expect(treeViewGitStatus.subscriptionsOfCommands).toBeNull()
      expect(treeViewGitStatus.toggledSubscriptions).toBeNull()
      expect(treeViewGitStatus.treeView).toBeNull()
      expect(treeViewGitStatus.repos).toBeNull()
      expect(treeViewGitStatus.treeViewUI).toBeNull()
      expect(treeViewGitStatus.ignoredRepositories).toBeNull()

    it 'destroys the Git Status elements that were added to the DOM', ->
      for root in treeView.roots
        expect(root.header.querySelector('span.tree-view-git-status'))
          .not.toExist()

    it 'removes the Git Status CSS classes that were added to the DOM', ->
      for root in treeView.roots
        expect(root.classList.contains('status-modified')).toBe(false)
        expect(root.classList.contains('status-added')).toBe(false)

  awaitCallback = (scope, handler) ->
    return new Promise (resolve, reject) ->
      subscription = handler.call(scope, () ->
          subscription.dispose() if subscription?.dispose?
          resolve()
        )

  waitForPackageActivation = (pkgName, handler) ->
    waitsForPromise ->
      atom.packages.activatePackage(pkgName)
        .then(->
            return unless handler
            handler(atom.packages.getActivePackage(pkgName))
          )

  prepareProject = (repoPath, noGit) ->
    runs () ->
      if noGit?
        projPaths = [path.join(fixturesPath, repoPath)]
      else
        projPaths = [extractGitRepoFixture(fixturesPath, repoPath)]
      atom.project.setPaths(projPaths)
      validateProjectPaths projPaths
      unlockWaitFor = false

      expect(treeViewGitStatus.toggled).toBe(true)
      expect(treeViewGitStatus.getRepositories()).not.toBeNull()
      expect(atom.project.getRepositories().length).toBe(1)

      handler = treeViewGitStatus.repos.onDidChange 'repos', () ->
        handler.dispose()
        unlockWaitFor = true

    waitsFor(
      () ->
        return unlockWaitFor
      , 'Wait for repo update', defaultDelay + 1000
    )

  idle = (timeout) ->
    runs ->
      unlockWaitFor = false
      intFct = setInterval (->
        unlockWaitFor = true
        clearInterval(intFct)
      ), timeout
    waitsFor (->
      return unlockWaitFor
    ), 'Wait idle unlock', timeout + defaultDelay + 1000

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
