var exec = require('cordova/exec');
/**
 * Constructor
 */
module.exports = {
    init: function(success, failure) {
        exec(success, failure, 'Ar530Plugin', 'init', []);
    },

    setConfiguration: function(configurationDictionary, success, failure) {
        var configurationArray = new Array();
        var keyArray = new Array("scanPeriod");
        // convert dictionary to array
        for (index in keyArray) {
            if (typeof configurationDictionary[keyArray[index]] === 'undefined') {
                configurationArray.push("unchanged");
            } else {
                configurationArray.push(configurationDictionary[keyArray[index]]);
            }
        }
        exec(success, failure, "Ar530Plugin", "setConfiguration", configurationArray);
    },

    addTagDiscoveredListener: function(resultCallback, success, failure) {
        exec(
            function(tagUid) { resultCallback({ tagUid: tagUid }) },
            function(failure) { console.log("ERROR: Ar530Plugin.addTagDiscoveredListener: " + failure) },
            "Ar530Plugin", "setTagDiscoveredCallback", []);
    }
}