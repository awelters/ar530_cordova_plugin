# Cordova Plugin for Feitian aR530 Audiojack NFC reader SDK

## Installation

- Create your Cordova app.

```bash
cordova create ar530-plugin-example-app && cd $_
```

- Add the plugin to it.

```bash
cordova plugin add https://github.com/awelters/ar530_cordova_plugin#<latest-commit-code>
```

- Implement a simple code snippet to test your setup.

```
var app = {

    // Application Constructor
    initialize: function() {
        document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
    },

    // deviceready Event Handler
    //
    // Bind any cordova events here. Common events are:
    // 'pause', 'resume', etc.
    onDeviceReady: function() {
        var configuration = {
            shouldPoll: 0,  // 1 for nfc polling, 0 on demand
            scanPeriod: 30000 // if shouldPoll == 0 then scanPeriod must be >= 1000 ms
        }
        ar530Plugin.addConnectedListener(function(isConnected) {
            console.log("isConnected",isConnected);
            ar530Plugin.scanForTag();
        });
        ar530Plugin.addTagDiscoveredListener(function(result) {
            console.log(result);
        });
        ar530Plugin.init(configuration);
    }

};

app.initialize();
```

## API

**Required for operation**

* `init()`

	Initialises and configures the plugin, preparing it for first use in the current session

    ```
    Object configuration
    {
        int shouldPoll,  // 1 for polling, 0 for on demand tag scans
        int scanPeriod  // if shouldPoll == 0 then scanPeriod must be >= 1000 ms
    }

    e.g
    let configuration = {}
      configuration = {
        shouldPoll: 0,
        scanPeriod: 30000
      }

      ar530Plugin.init(configuration);
    ```

**Optional methods**

* `configure()`

	Reconfigures plugin.  See init function for configuration object details.

	```
      ar530Plugin.configure(configuration);
	```

* `scanForTag()`

	Scan for tags.

	```
      ar530Plugin.scanForTag();
	```
	
* `stopScanForTag()`

	Stops scanning for tags.

	```
      ar530Plugin.stopScanForTag();
	```

* `getDeviceInfo(resultCallback)`

	Assign a callback function to get the device info of the reader

	```
      	ar530Plugin.getDeviceInfo(resultCallback);
      
      	function resultCallback(result)
	Object result
	{
		String libVersion,
		String deviceID,
		String firmwareVersion,
		String deviceUID
	}
	```

* `addTagDiscoveredListener(resultCallback)`

	Assign a callback function to fire when the UID of a tag is found by any reader (and all the memory if it is a Mifare Ultralight C tag aka payload otherwise the payload is an empty string)

	```
	function resultCallback(result)
	Object result
	{
		String tagUid,
		String payload
	}
	```
