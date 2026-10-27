# Native iPad companion

The iPad app is listed as **Fatty Lumpkin Screenshot Tool**. It uses SwiftUI, PencilKit, and VisionKit QR scanning, with no third-party SDKs.

See [build instructions](../docs/BUILDING.md), [setup](../docs/GETTING-STARTED.md), and [architecture](../docs/ARCHITECTURE.md).

The native app and Safari companion share the same local Mac protocol, but keep their pairing credentials and unfinished drafts separately. Saves are full-resolution flattened PNGs, limited to 16 million pixels. Local retry data includes a stable submission ID so a dropped response does not duplicate an export.

Run the ScreenshotTool scheme’s tests on an iPad simulator. The tests cover capture validation, pairing URL validation, queue order, export dimensions and ink, draft recovery, authenticated saves, and unauthorized responses.
