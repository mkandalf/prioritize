

# Hook for action after the extension is installed
onInstall = ->
    localStorage['needsHelp'] = true
    chrome.tabs.getSelected (tab) ->
        chrome.tabs.update tab.id, {'url': "http://mail.google.com"}
    null


# Hook for action after the extension is updated (version change)
onUpdate = ->
    alert "Extension Updated"
    null


# Get the version of this app
getVersion = ->
    details = chrome.app.getDetails()
    details.version


# Current version of this app
currVersion = getVersion()
# User's version of this app
prevVersion = localStorage['version']

# Check if the installation version matches
# If not, activate hooks as needed
if (currVersion != prevVersion)
    if (typeof prevVersion == 'undefined')
        onInstall()
    else
        onUpdate()
    localStorage['version'] = currVersion

# Event listener for content scripts
chrome.extension.onRequest.addListener (request, sender, sendResponse) ->
    # Let a content script retrieve a value from local storage
    # parameters: key
    if (request.method == "getLocalStorage")
        sendResponse {data: localStorage[request.key]}
    # let a content script set a value to local storage
    # parameters: key, value
    else if (request.method == "setLocalStorage")
        localStorage[request.key] = request.value
        sendResponse {data: localStorage[request.key]}
    else
        sendResponse {} # snub them.
