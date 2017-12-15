# Cordova Plugin for Feitian aR530 Audiojack NFC reader SDK

## Installation

- Create your Cordova app.

```bash
cordova create ar530-plugin-example-app && cd $_
```

- Add the plugin to it.

```bash
cordova plugin add https://github.com/awelters/...#<latest-commit-code>
```

- Implement a simple code snippet to test your setup.

```
ar530Plugin.init();
```

## API

**Required for operation**

* `init()`

	Initialises the plugin, preparing it for first use in the current session


**Optional methods**

* `setConfiguration(configuration)`

	Configures settings for the current session.

	```
	Object configuration
	{
		int scanPeriod,  // scan period in ms
	}

	e.g
	let configuration = {}
      configuration = {
        scanPeriod: 1000,  // scan period in ms
      }

      ar530Plugin.setConfiguration(configuration);
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