
module.exports = class GitRepositoryAsync

  repo: null

  constructor: (@repo) ->

  destruct: ->
    @repo = null

  getShortHead: ->
    return Promise.resolve()
      .then => @repo.getShortHead()

  getWorkingDirectory: ->
    return Promise.resolve()
      .then => @repo.getWorkingDirectory()

  onDidChangeStatuses: (callback) ->
    return @repo.onDidChangeStatuses(callback)

  onDidChangeStatus: (callback) ->
    return @repo.onDidChangeStatus(callback)

  getDirectoryStatus: (path) ->
    return Promise.resolve()
      .then => @repo.getDirectoryStatus(path)

  getRootDirectoryStatus: ->
    return Promise.resolve().then =>
      directoryStatus = 0
      for path, status of @repo.statuses
        directoryStatus |= status
      return directoryStatus

  ###
   * Returns the usual configuration for Git Flow, which includes the prefixes
   * for each kind of branch.
   *
   * @return {Object} Git Flow information
  ###
  getFlowConfig: ->
    # Use a Promise to determine what each prefix is and where the `master`
    # and `develop` branches are
    return Promise.resolve().then => {
      master: @repo.getConfigValue 'gitflow.branch.master'
      develop: @repo.getConfigValue 'gitflow.branch.develop'
      feature: @repo.getConfigValue 'gitflow.prefix.feature'
      release: @repo.getConfigValue 'gitflow.prefix.release'
      hotfix: @repo.getConfigValue 'gitflow.prefix.hotfix'
    }

  refreshStatus: ->
    return Promise.resolve()

  getCachedUpstreamAheadBehindCount: (path) ->
    return Promise.resolve()
      .then => @repo.getCachedUpstreamAheadBehindCount(path)

  isStatusModified: (status) ->
    return @repo.isStatusModified(status)

  isStatusNew: (status) ->
    return @repo.isStatusNew(status)
