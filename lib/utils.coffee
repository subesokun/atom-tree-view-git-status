fs = require 'fs'
path = require 'path'

normalizePath = (repoPath) ->
  normPath = (path.normalize repoPath).replace(/[\\\/]$/, '')
  if process.platform is 'darwin'
    # For some reason the paths returned by the tree-view and
    # git-utils are sometimes "different" on Darwin platforms.
    # E.g. /private/var/... (real path) !== /var/... (symlink)
    # For now just strip away the /private part.
    normPath = normPath.replace(/^\/private/, '')
  try
    # Finally try to resolve the real path to avoid issues with symlinks.
    return fs.realpathSync(normPath)
  catch e
    # If the path doesn't exists `realpath` throws an error.
    # In that case just return the normalized path.
    return normPath

getRootDirectoryStatus = (repo) ->
  promise = Promise.resolve()
  if repo._getStatus? or repo.repo._getStatus?
    # Workaround for Atom < 1.9 as still this root directory status bug
    # exists and the _getStatus function has been moved into ohnogit
    if repo._getStatus?
      promise = promise.then ->
        return repo._getStatus(['**'])
    else
      promise = promise.then ->
        return repo.repo._getStatus(['**'])
    return promise
      .then (statuses) ->
        return Promise.all(
          statuses.map((s) -> s.statusBit())
        ).then (bits) ->
          reduceFct = (status, bit) ->
            return status | bit
          return bits
            .filter((b) -> b > 0)
            .reduce(reduceFct, 0)
  # Atom >= 1.9 with our own GitRepositoryAsync wrapper
  return repo.getRootDirectoryStatus()

# Wait until all prmoises have been settled even thought a promise has
# been rejected.
settle = (promises) ->
  promiseWrapper = (promise) ->
    return promise
      .then((result) ->
        return { resolved: result }
      )
      .catch((err) ->
        console.error err
        return { rejected: err }
      )
  return Promise.all(promises.map(promiseWrapper))
    .then (results) ->
      rejectedPromises = results.filter (p) -> p.hasOwnProperty('rejected')
      strippedResults = results.map (r) -> r.resolved || r.rejected
      if rejectedPromises.length is 0
        return strippedResults
      else
        return Promise.reject(strippedResults)

module.exports = {
  normalizePath: normalizePath,
  getRootDirectoryStatus: getRootDirectoryStatus,
  settle: settle
}
