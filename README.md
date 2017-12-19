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
ar530Plugin.init();
```

## API

**Required for operation**

* `init()`

	Initialises and configures the plugin, preparing it for first use in the current session

    ```
    Object configuration
    {
        int shouldPoll,  // 1 for polling, 0 for on demand tag scans
    }

    e.g
    let configuration = {}
      configuration = {
        shouldPoll: 1
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