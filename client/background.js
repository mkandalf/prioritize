(function() {
  var currVersion, getVersion, onInstall, onUpdate, prevVersion;

  onInstall = function() {
    chrome.tabs.getSelected(function(tab) {
      return chrome.tabs.update(tab.id, {
        'url': "http://mail.google.com"
      });
    });
    return null;
  };

  onUpdate = function() {
    alert("Extension Updated");
    return null;
  };

  getVersion = function() {
    var details;
    details = chrome.app.getDetails();
    return details.version;
  };

  currVersion = getVersion();

  prevVersion = localStorage['version'];

  if (currVersion !== prevVersion) {
    if (typeof prevVersion === 'undefined') {
      onInstall();
    } else {
      onUpdate();
    }
    localStorage['version'] = currVersion;
  }

}).call(this);
