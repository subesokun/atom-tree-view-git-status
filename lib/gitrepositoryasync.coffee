
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

  refreshStatus: ->
    return Promise.resolve()

  getCachedUpstreamAheadBehindCount: (path) ->
    return Promise.resolve()
      .then => @repo.getCachedUpstreamAheadBehindCount(path)

  isStatusModified: (status) ->
    return @repo.isStatusModified(status)

  isStatusNew: (status) ->
    return @repo.isStatusNew(status)
