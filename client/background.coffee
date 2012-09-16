base_url = "http://value.herokuapp.com"

# Hook for action after the extension is installed
onInstall = ->
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
chrome.extension.onMessage.addListener (request, sender, sendResponse) ->
    # Let a content script retrieve a value from local storage
    # parameters: key
    if (request.method == "getLocalStorage")
        sendResponse {data: localStorage[request.key]}
    # let a content script set a value to local storage
    # parameters: key, value
    else if (request.method == "setLocalStorage")
        localStorage[request.key] = request.value
        sendResponse {data: localStorage[request.key]}
    else if (request.method == "getUser")
        $.ajax {
            url: "#{base_url}/users/lookup/",
            data: {email: request.email},
            type: "get",
            xhrFields: {
               withCredentials: true
            },
            dataType: "json",
            success: (data) ->
                console.log data
                sendResponse {data: data}
        }
        true
    else if (request.method == "makePayment")
        $.post "#{base_url}/users/#{request.to}/payments/new"
        ,   amount: request.amount
        ,   (data) ->
                sendResponse {data: data}
        true
    else if (request.method == "chargePayment")
        $.post "#{base_url}/payments/execute"
        ,   amount: request.amount
            from: request.from
        ,   (data) ->
                sendResponse {data: data}
        true
    else
        sendResponse {} # snub them.
