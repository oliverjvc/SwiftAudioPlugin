# Logic Pro Audio Unit diagnostics

[Download the diagnostic ZIP](./SwiftAudioPlugin-diagnostics.zip?raw=true).

On the affected Mac, extract the ZIP and open `Collect-Diagnostics.command` before changing Rosetta mode, reinstalling plug-ins or resetting caches. The collector saves Audio Unit registrations, installed component paths, version and hash details, and relevant crash-report paths to a new folder on the Desktop. It leaves Logic, plug-ins and caches untouched.

Review the report before sharing it because it includes local paths and installed plug-in names. Include one affected plug-in name, its status in Logic Plug-in Manager, and any change to Logic’s Rosetta setting.

See the [troubleshooting guide](https://github.com/oliverjvc/SwiftAudioPlugin/blob/main/README.md#troubleshooting-missing-logic-pro-plug-ins-on-apple-silicon).
