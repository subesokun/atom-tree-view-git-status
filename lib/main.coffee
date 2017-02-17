{CompositeDisposable, Emitter} = require 'atom'
ProjectRepositories = require './repositories'
TreeViewUI = require './treeviewui'
utils = require './utils'

module.exports = TreeViewGitStatus =

  config:
    autoToggle:
      type: 'boolean'
      default: true
      description:
        'Show the Git status in the tree view when starting Atom'
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
  toggledSubscriptions: null
  treeView: null
  subscriptionsOfCommands: null
  active: false
  repos: null
  treeViewUI: null
  ignoredRepositories: null
  emitter: null

  activate: ->
    @emitter = new Emitter
    @ignoredRepositories = new Map
    @subscriptionsOfCommands = new CompositeDisposable
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.packages.onDidActivateInitialPackages =>
      @doInitPackage()
    # Workaround for the isse that "onDidActivateInitialPackages" never gets
    # fired if one or more packages are failing to initialize
    @activateInterval = setInterval (=>
        @doInitPackage()
      ), 1000
    @doInitPackage()

  doInitPackage: ->
    # Check if the tree view has been already initialized
    treeView = @getTreeView()
    return unless treeView and not @active

    clearInterval(@activateInterval)
    @treeView = treeView
    @active = true

    # Toggle tree-view-git-status...
    @subscriptionsOfCommands.add atom.commands.add 'atom-workspace',
      'tree-view-git-status:toggle': =>
        @toggle()
    autoToggle = atom.config.get 'tree-view-git-status.autoToggle'
    @toggle() if autoToggle
    @emitter.emit 'did-activate'

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null
    @subscriptionsOfCommands?.dispose()
    @subscriptionsOfCommands = null
    @toggledSubscriptions?.dispose()
    @toggledSubscriptions = null
    @treeView = null
    @active = false
    @toggled = false
    @ignoredRepositories?.clear()
    @ignoredRepositories = null
    @repos?.destruct()
    @repos = null
    @treeViewUI?.destruct()
    @treeViewUI = null
    @emitter?.clear()
    @emitter?.dispose()
    @emitter = null

  toggle: ->
    return unless @active
    if not @toggled
      @toggled = true
      @repos = new ProjectRepositories(@ignoredRepositories)
      @treeViewUI = new TreeViewUI @treeView, @repos.getRepositories()
      @toggledSubscriptions = new CompositeDisposable
      @toggledSubscriptions.add(
        @repos.onDidChange 'repos', (repos) =>
          @treeViewUI?.setRepositories repos
      )
      @toggledSubscriptions.add(
        @repos.onDidChange 'repo-status', (evt) =>
          if @repos?.getRepositories().has(evt.repoPath)
            @treeViewUI?.updateRootForRepo(evt.repo, evt.repoPath)
      )
    else
      @toggled = false
      @toggledSubscriptions?.dispose()
      @toggledSubscriptions = null
      @repos?.destruct()
      @repos = null
      @treeViewUI?.destruct()
      @treeViewUI = null

  getTreeView: ->
    if not @treeView?
      if atom.packages.getActivePackage('tree-view')?
        treeViewPkg = atom.packages.getActivePackage('tree-view')
      # TODO Check for support of Nuclide Tree View
      if treeViewPkg?.mainModule?.treeView?
        return treeViewPkg.mainModule.treeView
      else
        return null
    else
      return @treeView

  getRepositories: ->
    return if @repos? then @repos.getRepositories() else null

  ignoreRepository: (repoPath) ->
    @ignoredRepositories.set(utils.normalizePath(repoPath), true)
    @repos?.setIgnoredRepositories(@ignoredRepositories)

  onDidActivate: (handler) ->
    return @emitter.on 'did-activate', handler
