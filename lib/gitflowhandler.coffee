{CompositeDisposable} = require 'atom'
GitRepositoryAsync = require './gitrepositoryasync'

flowIconMap =
  feature: 'puzzle'
  release: 'package'
  hotfix: 'flame'
  develop: 'home'
  master: 'verified'


class GitFlowData
  master: null
  develop: null
  feature: null
  release: null
  hotfix: null

  constructor: (repo) ->
    return unless repo instanceof GitRepositoryAsync
    repo = repo.repo
    @master = repo.getConfigValue('gitflow.branch.master')
    @develop = repo.getConfigValue('gitflow.branch.develop')
    @feature = repo.getConfigValue('gitflow.prefix.feature')
    @release = repo.getConfigValue('gitflow.prefix.release')
    @hotfix = repo.getConfigValue('gitflow.prefix.hotfix')


module.exports = class GitFlowHandler
  treeViewUi: null
  subscriptions: null

  constructor: (@treeViewUi) ->
    @gitFlowEnabled =
      atom.config.get('tree-view-git-status.gitFlow.enabled')
    @gitFlowDisplayType =
      atom.config.get('tree-view-git-status.gitFlow.display_type')
    @subscriptions = new CompositeDisposable
    @subscribeUpdateConfigurations()

  destruct: ->
    @subscriptions?.dispose()
    @subscriptions = null

  subscribeUpdateConfigurations: ->
    @subscriptions.add(
      atom.config.observe 'tree-view-git-status.gitFlow.enabled',
        (newValue) =>
          if @gitFlowEnabled isnt newValue
            @gitFlowEnabled = newValue
            @updateRoots()
    )
    @subscriptions.add(
      atom.config.observe 'tree-view-git-status.gitFlow.display_type',
        (newValue) =>
          if @gitFlowDisplayType isnt newValue
            @gitFlowDisplayType = newValue
            @updateRoots()
    )

  updateRoots: ->
    @treeViewUi.updateRoots()

  startsWith = (name, prefix) ->
    prefix == name.substr(0, prefix.length)

  getFlowConfig: (repo) -> new GitFlowData(repo)

  applyGitFlowConfig: (node, gitFlow) ->
    return unless node and gitFlow and @gitFlowEnabled
    branchPrefix = ''
    branchName = node.textContent
    workType = branchName
    # Add Git Flow information
    if gitFlow.feature? and startsWith(branchName, gitFlow.feature)
      stateName = 'feature'
      branchPrefix = gitFlow.feature
      workType = 'a feature'
    else if gitFlow.release? and startsWith(branchName, gitFlow.release)
      stateName = 'release'
      branchPrefix = gitFlow.release
      workType = 'a release'
    else if gitFlow.hotfix? and startsWith(branchName, gitFlow.hotfix)
      stateName = 'hotfix'
      branchPrefix = gitFlow.hotfix
      workType = 'a hotfix'
    else if gitFlow.develop? and branchName == gitFlow.develop
      stateName = 'develop'
    else if gitFlow.master? and branchName == gitFlow.master
      stateName = 'master'
    else
      # We're not on a Git Flow branch, don't do anything
      return
    # Add a data-flow attribute
    node.dataset.gitFlowState = stateName
    node.innerText = ''
    node.classList.add(
      'branch-label--flow',
      "branch-label--flow-#{stateName}"
    )
    # Remove the prefix from the branchname, or move the branchname to the
    # prefix in case of master / develop
    if branchPrefix
      branchName = branchName.substr(branchPrefix.length)
    else
      branchPrefix = branchName
      branchName = ''
    # If we want to use icons, make sure we remove the prefix
    if @gitFlowDisplayType > 1
      iconNode = document.createElement('span')
      iconNode.classList.add(
        "icon",
        "icon-#{flowIconMap[stateName]}"
        'branch-label__icon'
        "branch-label__icon--#{stateName}"
      )
      iconNode.title = "Working on #{workType}"
      node.appendChild(iconNode)
    # If we're asked to display the prefix or we're on master/develop, display
    # it.
    if branchName == '' or @gitFlowDisplayType < 3
      prefixNode = document.createElement('span')
      prefixNode.classList.add(
        'branch-label__prefix'
        "branch-label__prefix--#{stateName}"
      )
      prefixNode.textContent = branchPrefix
      node.appendChild(prefixNode)
    # Finally, if we have a branchname left over, add it as well.
    if branchName != ''
      node.appendChild(document.createTextNode(branchName))

  convertDirectoryStatus: (repo, status) ->
    newStatus = null
    if repo.isStatusModified(status)
      newStatus = 'modified'
    else if repo.isStatusNew(status)
      newStatus = 'added'
    return newStatus

  enhanceBranchName: (node, repo) ->
    if not @gitFlowEnabled
      return Promise.resolve()
    return new Promise((resolve, reject) =>
      flowData = @getFlowConfig(repo)
      if flowData
        @applyGitFlowConfig(node, flowData)
      resolve()
    )
