{CompositeDisposable, Emitter} = require 'atom'
utils = require './utils'

module.exports = class ProjectRepositories

  projectSubscriptions: null
  repositorySubscriptions: null

  constructor: ->
    @emitter = new Emitter
    @ignoredRepositories = new Map
    @repositoryMap = new Map
    @projectSubscriptions = new CompositeDisposable
    @repositorySubscriptions = new CompositeDisposable
    @projectSubscriptions.add atom.project.onDidChangePaths =>
      # Refresh SCM respority subscriptions
      @subscribeUpdateRepositories()
    @subscribeUpdateRepositories()

  destruct: ->
    @projectSubscriptions?.dispose()
    @projectSubscriptions = null
    @repositorySubscriptions?.dispose()
    @repositorySubscriptions = null
    @ignoredRepositories?.clear()
    @ignoredRepositories = null
    @repositoryMap = null
    @emitter?.clear()
    @emitter?.dispose()
    @emitter = null

  subscribeUpdateRepositories: ->
    @repositorySubscriptions?.dispose()
    tmpRepositorySubscriptions = new CompositeDisposable
    repositoryMap = new Map()
    repoPromises = []
    for repo in atom.project.getRepositories() when repo?
      repoPromises.push @doSubscribeUpdateRepository(
        repo, repositoryMap, tmpRepositorySubscriptions
      )
    return Promise.all(repoPromises)
      .then(() =>
        # Verify if the repositories instance haven't been yet
        # destructed (i.e. if we are still "toggled")
        if @repositoryMap?
          @repositorySubscriptions = tmpRepositorySubscriptions
          @repositoryMap = repositoryMap
          @emitter.emit 'did-change-repos', @repositoryMap
        else
          tmpRepositorySubscriptions.dispose()
      )

  doSubscribeUpdateRepository: (repo, repositoryMap, repositorySubscriptions) ->
    if repo.async?
      repoasync = repo.async
      # Validate repo to avoid errors from thirdparty repo handlers
      return repoasync.getShortHead()
        .then((shortHead) ->
          if not typeof shortHead is 'string'
            return Promise.reject('Got invalid short head for repo')
        )
        .then(() =>
          return repoasync.getWorkingDirectory()
            .then((directory) =>
              if not typeof directory is 'string'
                return Promise.reject(
                  'Got invalid working directory path for repo'
                )
              if !@isRepositoryIgnored(directory)
                repoPath = utils.normalizePath(directory)
                repositoryMap.set repoPath, repoasync
                @subscribeToRepo repoPath, repoasync, repositorySubscriptions
            )
        )
        .catch((error) ->
          console.warn 'Ignoring respority:', error, repo
          return Promise.resolve()
        )

  subscribeToRepo: (repoPath, repo, repositorySubscriptions) ->
    repositorySubscriptions?.add repo.onDidChangeStatuses =>
      # Sanity check
      if @repositoryMap?.has(repoPath)
        @emitter?.emit 'did-change-repo-status', { repo, repoPath }
    repositorySubscriptions?.add repo.onDidChangeStatus =>
      # Sanity check
      if @repositoryMap?.has(repoPath)
        @emitter?.emit 'did-change-repo-status', { repo, repoPath }

  getRepositories: () ->
    return @repositoryMap

  ignoreRepository: (repoPath) ->
    @ignoredRepositories.set(repoPath, true)
    @subscribeUpdateRepositories()

  isRepositoryIgnored: (repoPath) ->
    return @ignoredRepositories.has(repoPath)

  onDidChange: (evtType, handler) ->
    return @emitter.on 'did-change-' + evtType, handler
