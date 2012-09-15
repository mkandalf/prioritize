

onInstall = ->
    chrome.tabs.getSelected (tab) ->
        chrome.tabs.update tab.id, {'url': "http://mail.google.com"}
    null


onUpdate = ->
    alert "Extension Updated"
    null


getVersion = ->
    details = chrome.app.getDetails()
    details.version


currVersion = getVersion()
prevVersion = localStorage['version']
if (currVersion != prevVersion)
    if (typeof prevVersion == 'undefined')
        onInstall()
    else
        onUpdate()
    localStorage['version'] = currVersion
