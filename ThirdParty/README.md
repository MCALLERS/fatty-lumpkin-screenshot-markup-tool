# Bundled runtime notices

The Mac download bundles CPython 3.14.10 from Astral python-build-standalone release 20261026 (aarch64-apple-darwin, pgo+lto), and the PyInstaller 6.22.3 bootloader. Python and its compiled extension dependencies are provided under the notices in this directory, extracted from that runtime distribution’s PYTHON.json license references. Some notices apply to standard-library functionality not used by this app. The bootloader license includes an exception permitting applications to be distributed under their own license.

Source and distribution details: https://github.com/astral-sh/python-build-standalone/releases/tag/20261026 and https://github.com/pyinstaller/pyinstaller/tree/v6.22.3 . System frameworks are supplied by macOS. The iPad app uses Apple system frameworks and no third-party SDKs.

These notices are also included in the Mac app at Contents/Resources/ThirdParty. Recheck dependencies and notices whenever changing the bundled runtime.
