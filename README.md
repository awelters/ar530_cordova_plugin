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
        this.receivedEvent('deviceready');
        var configuration = {
            shouldPoll: 0,  // 1 for nfc polling, 0 on demand
            healthCheckPeriod: 30000 //0 will turn off health check, else >= 1000 ms
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
        int healthCheckPeriod  //0 will turn off health check, else >= 1000 ms
    }

    e.g
    let configuration = {}
      configuration = {
        shouldPoll: 0,
        healthCheckPeriod: 30000
      }

      ar530Plugin.init(configuration);
    ```

**Optional methods**

* `scanForTag()`

	If not polling then call this method to scan for a tag now.

	```
      ar530Plugin.scanForTag();
	```

* `addTagDiscoveredListener(resultCallback)`

	Assign a callback function to fire when the UID of a tag is found by any reader

	```
	function resultCallback(result)
	Object result
	{
		String tagUid
	}
	```