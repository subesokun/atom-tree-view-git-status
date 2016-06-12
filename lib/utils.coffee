path = require 'path'

normalizePath = (repoPath) ->
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
  return normPath.replace(/[\\\/]$/, '')

getRootDirectoryStatus = (repo) ->
  # Workaround for Atom 1.9 as still this root directory status bug exists and
  # the _getStatus function has been moved into ohnogit
  promise = Promise.resolve()
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

module.exports = {
  normalizePath: normalizePath,
  getRootDirectoryStatus: getRootDirectoryStatus
}
