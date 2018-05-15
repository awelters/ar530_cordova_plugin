var exec = require('cordova/exec');

/**

 * Constructor

 */

var configFn = function(configurationDictionary, success, failure, fnName) {

   var configurationArray = new Array();

   var keyArray = new Array("shouldPoll", "scanPeriod");

   // convert dictionary to array

   for (index in keyArray) {

       if (typeof configurationDictionary[keyArray[index]] === 'undefined') {

           configurationArray.push("0");

       } else {

           configurationArray.push(configurationDictionary[keyArray[index]]);

       }

   }



    exec(success, failure, 'Ar530Plugin', fnName, configurationArray);

};

module.exports = {

    init: function(configurationDictionary, success, failure) {

       configFn(configurationDictionary, success, failure, 'init');

    },

    configure: function(configurationDictionary, success, failure) {

       configFn(configurationDictionary, success, failure, 'configure');

    },

    scanForTag: function(success, failure) {

        exec(success, failure, "Ar530Plugin", "scanForTag", []);

    },

    stopScanForTag: function(success, failure) {

        exec(success, failure, "Ar530Plugin", "stopScanForTag", []);

    },

    playSound: function(success, failure) {

        exec(success, failure, "Ar530Plugin", "playSound", []);

    },

    disableSound: function(success, failure) {

        exec(success, failure, "Ar530Plugin", "disableSound", []);

    },

    getDeviceInfo: function(resultCallback, success, failure) {

        exec(

            function(libVersion,deviceID,firmwareVersion,deviceUID) { resultCallback({ libVersion: libVersion, deviceID: deviceID, firmwareVersion: firmwareVersion, deviceUID: deviceUID }) },

            function(failure) { console.log("ERROR: Ar530Plugin.getDeviceInfo: " + failure) },

            "Ar530Plugin", "getDeviceInfo", []);

    },

   addConnectedListener: function(resultCallback, success, failure) {

        exec(

             function(isConnected) { resultCallback(isConnected) },

             function(failure) { console.log("ERROR: Ar530Plugin.addConnectedListener: " + failure) },

             "Ar530Plugin", "setDeviceConnectedCallback", []);

   },



    addTagDiscoveredListener: function(resultCallback, success, failure) {

        exec(

            function(tagUid,payload) { resultCallback({ tagUid: tagUid, payload: payload }) },

            function(failure) { console.log("ERROR: Ar530Plugin.addTagDiscoveredListener: " + failure) },

            "Ar530Plugin", "setTagDiscoveredCallback", []);

    },

    addDebugListener: function(resultCallback, success, failure) {

        exec(

             function(msg) { resultCallback(msg) },

             function(failure) { console.log("ERROR: Ar530Plugin.addDebugListener: " + failure) },

             "Ar530Plugin", "setDebugCallback", []);

    }

}
