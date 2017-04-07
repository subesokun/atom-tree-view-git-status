###
Handles Git Flow handling and highlighting

@author Roelof Roos <github@roelof.io>
###

{CompositeDisposable} = require 'atom'
GitRepositoryAsync = require './gitrepositoryasync'

flowIconMap =
  feature: 'puzzle'
  release: 'package'
  hotfix: 'flame'
  develop: 'home'
  master: 'verified'

###
Datamodel for the Git Flow information
###
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

###
Handles all git flow systems
###
module.exports = class GitFlowHandler
  treeViewUi: null
  subscriptions: null

  constructor: (@treeViewUi) ->
    @gitFlowEnabled =
      atom.config.get 'tree-view-git-status.git_flow.enabled'
    @gitFlowDisplayType =
      atom.config.get 'tree-view-git-status.git_flow.display_type'

    @subscriptions = new CompositeDisposable

    @subscribeUpdateConfigurations()

  destruct: ->
    @subscriptions?.dispose()
    @subscriptions = null

  subscribeUpdateConfigurations: ->
    @subscriptions.add(
      atom.config.observe 'tree-view-git-status.git_flow.enabled',
        (newValue) =>
          if @gitFlowEnabled isnt newValue
            @gitFlowEnabled = newValue
            @updateRoots()
    )
    @subscriptions.add(
      atom.config.observe 'tree-view-git-status.git_flow.display_type',
        (newValue) =>
          if @gitFlowDisplayType isnt newValue
            @gitFlowDisplayType = newValue
            @updateRoots()
    )

  updateRoots: ->
    @treeViewUi.updateRoots()

  ###
  Short method to determine the start of a branch. Since it's used
  repeatedly
  @param  {string} name   [description]
  @param  {string} prefix [description]
  @return [bool] Returns true if
  ###
  startsWith = (name, prefix) ->
    prefix == name.substr 0, prefix.length

  ###
  Returns the usual configuration for Git Flow, which includes the prefixes
  for each kind of branch.

  @return {GitFlowData} Git Flow information
  ###
  getFlowConfig: (repo) -> new GitFlowData(repo)

  ###
  Applies Git Flow branding to the given node.

  @param  {DOMElement} node
  @param  {GitFlowData} gitFlow
  @return {null}
  ###
  applyGitFlowConfig: (node, gitFlow) ->
    console.log(
      'Data dump!',
      @gitFlowEnabled,
      gitFlow,
      node
    )
    return unless node and gitFlow and @gitFlowEnabled

    branchPrefix = ''
    branchName = node.textContent
    workType = branchName

    # Add Git Flow information
    if gitFlow.feature? and startsWith branchName, gitFlow.feature
      stateName = 'feature'
      branchPrefix = gitFlow.feature
      workType = 'a feature'
    else if gitFlow.release? and startsWith branchName, gitFlow.release
      stateName = 'release'
      branchPrefix = gitFlow.release
      workType = 'a release'
    else if gitFlow.hotfix? and startsWith branchName, gitFlow.hotfix
      stateName = 'hotfix'
      branchPrefix = gitFlow.hotfix
      workType = 'a hotfix'
    else if gitFlow.develop? and branchName == gitFlow.develop
      stateName = 'develop'
    else if gitFlow.master? and branchName == gitFlow.master
      stateName = 'master'
    else
      # We're nog on a Git Flow branch, don't do anything
      return

    # Add a data-flow attribute
    node.dataset.gitFlowState = stateName

    # Empty node
    node.innerText = ''

    # Add class names
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
      node.appendChild iconNode

    # If we're asked to display the prefix or we're on master/develop, display
    # it.
    if branchName == '' or @gitFlowDisplayType < 3
      prefixNode = document.createElement('span')
      prefixNode.classList.add(
        'branch-label__prefix'
        "branch-label__prefix--#{stateName}"
      )
      prefixNode.textContent = branchPrefix
      node.appendChild prefixNode

    # Finally, if we have a branchname left over, add it as well.
    if branchName != ''
      node.appendChild document.createTextNode(branchName)

  convertDirectoryStatus: (repo, status) ->
    newStatus = null
    if repo.isStatusModified(status)
      newStatus = 'modified'
    else if repo.isStatusNew(status)
      newStatus = 'added'
    return newStatus

  ###
  Async all updating of the nodes and return that.
  ###
  enhanceBranchName: (node, repo) ->
    # Abort if GitFlow is disabled
    if not @gitFlowEnabled
      return Promise.resolve()

    console.log 'Starting promise'

    return new Promise((ok, fail) =>
      console.log 'Getting flow config'
      flowData = @getFlowConfig(repo)
      if flowData
        console.log 'Writing', flowData, 'to', node
        @applyGitFlowConfig(node, flowData)
      else
        console.log 'No flowdata to write to', node
      ok(null)
    )
