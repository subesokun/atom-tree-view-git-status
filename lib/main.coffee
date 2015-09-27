{CompositeDisposable} = require 'atom'
path = require 'path'
fs = require 'fs-plus'
TreeViewGitStatusTooltip = require './tooltip'

module.exports = TreeViewGitStatus =
  config:
    autoToggle:
      type: 'boolean'
      default: true
    showProjectModifiedStatus:
      type: 'boolean'
      default: true
      description:
        'Mark project folder as modified in case there are any ' +
        'uncommited changes'
    showBranchLabel:
      type: 'boolean'
      default: true
    showCommitsAheadLabel:
      type: 'boolean'
      default: true
    showCommitsBehindLabel:
      type: 'boolean'
      default: true

  subscriptions: null
  repositorySubscriptions: null
  repositoryMap: null
  treeView: null
  treeViewRootsMap: null
  roots: null
  showProjectModifiedStatus: true
  showBranchLabel: true
  showCommitsAheadLabel: true
  showCommitsBehindLabel: true
  subscriptionsOfCommands: null
  active: false
  ignoredRepositories: null

  activate: ->
    @active = true

    # Read configuration
    @showProjectModifiedStatus =
      atom.config.get 'tree-view-git-status.showProjectModifiedStatus'
    @showBranchLabel =
      atom.config.get 'tree-view-git-status.showBranchLabel'
    @showCommitsAheadLabel =
      atom.config.get 'tree-view-git-status.showCommitsAheadLabel'
    @showCommitsBehindLabel =
      atom.config.get 'tree-view-git-status.showCommitsBehindLabel'

    # Commands Subscriptions
    @subscriptionsOfCommands = new CompositeDisposable
    @subscriptionsOfCommands.add atom.commands.add 'atom-workspace',
      'tree-view-git-status:toggle': =>
        @toggle()

    @subscriptions = new CompositeDisposable
    @treeViewRootsMap = new Map
    @ignoredRepositories = new Map

    @toggle() if atom.config.get 'tree-view-git-status.autoToggle'

  deactivate: ->
    @subscriptions?.dispose()
    @repositorySubscriptions?.dispose()
    @subscriptionsOfCommands?.dispose()
    @clearTreeViewRootMap() if @treeView?
    @repositoryMap?.clear()
    @ignoredRepositories?.clear()
    @treeViewRootsMap = null
    @subscriptions = null
    @treeView = null
    @repositorySubscriptions = null
    @treeViewRootsMap = null
    @repositoryMap = null
    @ignoredRepositories = null
    @active = false
    @toggled = false

  toggle: ->
    return unless @active
    if @toggled
      @toggled = false
      @subscriptions?.dispose()
      @repositorySubscriptions?.dispose()
      @clearTreeViewRootMap() if @treeView?
      @repositoryMap?.clear()
    else
      @toggled = true
      # Setup subscriptions
      @subscriptions.add atom.project.onDidChangePaths =>
        @subscribeUpdateRepositories()
      @subscribeUpdateRepositories()
      @subscribeUpdateConfigurations()

      atom.packages.activatePackage('tree-view').then (treeViewPkg) =>
        return unless @active and @toggled
        @treeView = treeViewPkg.mainModule.createView()
        # Bind against events which are causing an update of the tree view
        @subscribeUpdateTreeView()
        # Update the tree roots
        @updateRoots true
      .catch (error) ->
        console.error error, error.stack

  clearTreeViewRootMap: ->
    @treeViewRootsMap?.forEach (root, rootPath) ->
      root.root?.classList?.remove('status-modified')
      customElements = root.customElements
      if customElements?.headerGitStatus?
        root.root?.header?.removeChild(customElements.headerGitStatus)
        customElements.headerGitStatus = null
      if customElements?.tooltip?
        customElements.tooltip.destruct()
        customElements.tooltip = null
    @treeViewRootsMap?.clear()

  subscribeUpdateConfigurations: ->
    atom.config.observe 'tree-view-git-status.showProjectModifiedStatus',
      (newValue) =>
        if @showProjectModifiedStatus isnt newValue
          @showProjectModifiedStatus = newValue
          @updateRoots()

    atom.config.observe 'tree-view-git-status.showBranchLabel',
      (newValue) =>
        if @showBranchLabel isnt newValue
          @showBranchLabel = newValue
          @updateRoots()

    atom.config.observe 'tree-view-git-status.showCommitsAheadLabel',
      (newValue) =>
        if @showCommitsAheadLabel isnt newValue
          @showCommitsAheadLabel = newValue
          @updateRoots()

    atom.config.observe 'tree-view-git-status.showCommitsBehindLabel',
      (newValue) =>
        if @showCommitsBehindLabel isnt newValue
          @showCommitsBehindLabel = newValue
          @updateRoots()

  subscribeUpdateTreeView: ->
    @subscriptions.add(
      atom.project.onDidChangePaths =>
        @updateRoots true
    )
    @subscriptions.add(
      atom.config.onDidChange 'tree-view.hideVcsIgnoredFiles', =>
        @updateRoots true
    )
    @subscriptions.add(
      atom.config.onDidChange 'tree-view.hideIgnoredNames', =>
        @updateRoots true
    )
    @subscriptions.add(
      atom.config.onDidChange 'core.ignoredNames', =>
        @updateRoots true if atom.config.get 'tree-view.hideIgnoredNames'
    )
    @subscriptions.add(
      atom.config.onDidChange 'tree-view.sortFoldersBeforeFiles', =>
        @updateRoots true
    )

  subscribeUpdateRepositories: ->
    @repositorySubscriptions?.dispose()
    @repositorySubscriptions = new CompositeDisposable
    @repositoryMap = new Map()
    for repo in atom.project.getRepositories() when repo?
      # Validate repo to avoid errors from thirdparty repo objects
      if repo.getShortHead? and
          typeof repo.getShortHead() is 'string' and
          repo.getWorkingDirectory? and
          typeof repo.getWorkingDirectory() is 'string' and
          repo.statuses? and
          not @isRepositoryIgnored(repo.getWorkingDirectory())
        @repositoryMap.set @normalizePath(repo.getWorkingDirectory()), repo
        @subscribeToRepo repo

  subscribeToRepo: (repo) ->
    @repositorySubscriptions.add repo.onDidChangeStatuses =>
      @updateRootForRepo repo
    @repositorySubscriptions.add repo.onDidChangeStatus =>
      @updateRootForRepo repo

  updateRoots: (reset) ->
    if @treeView?
      @roots = @treeView.roots
      @clearTreeViewRootMap() if reset
      for root in @roots
        rootPath = @normalizePath root.directoryName.dataset.path
        if reset
          @treeViewRootsMap.set(rootPath, {root, customElements: {}})
        repoForRoot = null
        repoSubPath = null
        rootPathHasGitFolder = fs.existsSync(path.join(rootPath, '.git'))
        @repositoryMap.forEach (repo, repoPath) ->
          if not repoForRoot? and ((rootPath is repoPath) or
              (rootPath.indexOf(repoPath) is 0 and not rootPathHasGitFolder))
            repoSubPath = path.relative repoPath, rootPath
            repoForRoot = repo
        if repoForRoot?
          if not repoForRoot?.repo?
            repoForRoot = null
          @doUpdateRootNode root, repoForRoot, rootPath, repoSubPath

  updateRootForRepo: (repo) ->
    if @treeView? and @treeViewRootsMap?
      repoPath = @normalizePath repo.getWorkingDirectory()
      @treeViewRootsMap.forEach (root, rootPath) =>
        if rootPath.indexOf(repoPath) is 0
          repoSubPath = path.relative repoPath, rootPath
          if not repo?.repo?
            repo = null
          @doUpdateRootNode root.root, repo, rootPath, repoSubPath if root.root?

  doUpdateRootNode: (root, repo, rootPath, repoSubPath) ->
    customElements = @treeViewRootsMap.get(rootPath).customElements
    isModified = false
    if @showProjectModifiedStatus and repo?
      if repoSubPath isnt '' and repo.getDirectoryStatus(repoSubPath) isnt 0
        isModified = true
      else if repoSubPath is ''
        # Workaround for the issue that 'getDirectoryStatus' doesn't work
        # on the repository root folder
        isModified = @isRepoModified repo
    if isModified
      root.classList.add('status-modified')
    else
      root.classList.remove('status-modified')

    showHeaderGitStatus = @showBranchLabel or @showCommitsAheadLabel or
        @showCommitsBehindLabel

    if showHeaderGitStatus and repo? and not customElements.headerGitStatus?
      headerGitStatus = document.createElement('span')
      headerGitStatus.classList.add('tree-view-git-status')
      @generateGitStatusText headerGitStatus, repo
      root.header.insertBefore(headerGitStatus, root.directoryName.nextSibling)
      customElements.headerGitStatus = headerGitStatus
    else if showHeaderGitStatus and customElements.headerGitStatus?
      @generateGitStatusText customElements.headerGitStatus, repo
    else if customElements.headerGitStatus?
      root.header.removeChild(customElements.headerGitStatus)
      customElements.headerGitStatus = null

    if repo? and not customElements.tooltip?
      customElements.tooltip = new TreeViewGitStatusTooltip(root, repo)

  generateGitStatusText: (container, repo) ->
    display = false
    head = repo?.getShortHead()
    ahead = behind = 0
    if repo.getCachedUpstreamAheadBehindCount?
      {ahead, behind} = repo.getCachedUpstreamAheadBehindCount() ? {}
    if @showBranchLabel and head?
      branchLabel = document.createElement('span')
      branchLabel.classList.add('branch-label')
      branchLabel.textContent = head
      display = true
    if @showCommitsAheadLabel and ahead > 0
      commitsAhead = document.createElement('span')
      commitsAhead.classList.add('commits-ahead-label')
      commitsAhead.textContent = ahead
      display = true
    if @showCommitsBehindLabel and behind > 0
      commitsBehind = document.createElement('span')
      commitsBehind.classList.add('commits-behind-label')
      commitsBehind.textContent = behind
      display = true

    if display
      container.classList.remove('hide')
    else
      container.classList.add('hide')

    container.innerHTML = ''
    container.appendChild branchLabel if branchLabel?
    container.appendChild commitsAhead if commitsAhead?
    container.appendChild commitsBehind if commitsBehind?

  isRepoModified: (repo) ->
    return Object.keys(repo.statuses).length > 0

  ignoreRepository: (repoPath) ->
    @ignoredRepositories.set(repoPath, true)
    @subscribeUpdateRepositories()
    @updateRoots(true)

  isRepositoryIgnored: (repoPath) ->
    return @ignoredRepositories.has(repoPath)

  normalizePath: (repoPath) ->
    normPath = path.normalize repoPath
    if process.platform is 'darwin'
      # For some reason the paths returned by the tree-view and
      # git-utils are sometimes "different" on Darwin platforms.
      # E.g. /private/var/... (real path) !== /var/... (symlink)
      # For now just strip away the /private part.
      # Using the fs.realPath function to avoid this issue isn't such a good
      # idea because it tries to access that path and in case it's not
      # existing path an error gets thrown + it's slow due to fs access.
      normPath = normPath.replace(/^\/private/, '')
    return normPath
