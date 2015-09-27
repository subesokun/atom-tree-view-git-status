
path = require 'path'

module.exports = class TreeViewGitStatusTooltip
  tooltip: null
  root: null
  repo: null
  mouseEnterSubscription: null

  constructor: (@root, @repo) ->
    root.header.addEventListener 'mouseenter', () => @onMouseEnter()

    @mouseEnterSubscription = dispose: =>
      @root.header.removeEventListener 'mouseenter', () => @onMouseEnter()
      @mouseEnterSubscription = null

  destruct: ->
    @destroyTooltip()
    @mouseEnterSubscription?.dispose()
    tooltip = null
    root = null
    repo = null

  destroyTooltip: ->
    @tooltip?.dispose()

  generateTooltipContent: ->
    tooltipItems = []
    branch =  @repo.branch ? null
    originURL = @repo.getOriginURL?() ? null
    workingDir = @repo.getWorkingDirectory?() ? null

    if branch?
      tooltipItems.push {'title': 'Head', 'content': branch}
    if originURL?
      tooltipItems.push {'title': 'Origin', 'content': originURL}
    if workingDir?
      tooltipItems.push {'title': 'Path', 'content':
        @shortenPath path.normalize workingDir}

    container = document.createElement('div')
    container.classList.add 'git-status-tooltip'
    titlesContainer = document.createElement('div')
    titlesContainer.classList.add 'titles-container'
    itemsContainer = document.createElement('div')
    itemsContainer.classList.add 'items-container'

    for item in tooltipItems
      titleElem = document.createElement('span')
      titleElem.classList.add 'title'
      titleElem.innerText = item.title
      titlesContainer.appendChild titleElem
      if typeof item.content is 'string'
        itemElem = document.createElement('span')
        itemElem.classList.add 'item'
        itemElem.innerText = item.content
        itemsContainer.appendChild itemElem
      else if item.content instanceof HTMLElement
        itemsContainer.appendChild item.content

    container.appendChild titlesContainer
    container.appendChild itemsContainer
    return container

  onMouseEnter: ->
    @destroyTooltip()
    # Validate reposiotry to make sure that it hasn't been destroyed
    # in the meantime
    if @repo?.repo?
      @tooltip = atom.tooltips.add @root.header,
        title: @generateTooltipContent()
        html: true
        placement: 'bottom'

  shortenPath: (dirPath) ->
    # Shorten path if possible
    if process.platform is 'win32'
      userHome = process.env.USERPROFILE
    else
      userHome = process.env.HOME
    normRootPath = path.normalize(dirPath)
    if normRootPath.indexOf(userHome) is 0
      # Use also tilde in case of Windows as synonym for the home folder
      '~' + normRootPath.substring(userHome.length)
    else
      dirPath
