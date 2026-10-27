import Foundation

/// Only touches screenshot location, format, and HDR; records absent keys too.
enum CaptureSettings {
    static let domain = "com.apple.screencapture" as CFString
    static let keys = ["location", "type", "captureHDR"]
    static func read(_ key: String) -> Any? {
        CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    static func isConfigured(for inbox: URL) -> Bool {
        guard let path = read("location") as? String else { return false }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL == inbox.standardizedFileURL && (read("type") as? String) == "png" && (read("captureHDR") as? Bool) == false
    }
    static func backupURL(_ state: URL) -> URL { state.appendingPathComponent("screenshot-settings-backup.plist") }
    static func configure(inbox: URL, state: URL) throws {
        try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: backupURL(state).path) {
            var values: [String: Any] = [:]
            for key in keys { values[key] = ["present": read(key) != nil, "value": read(key) ?? ""] }
            let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
            try data.write(to: backupURL(state), options: .atomic)
        }
        try write(["location": inbox.path, "type": "png", "captureHDR": false])
    }
    static func restore(state: URL) throws {
        guard FileManager.default.fileExists(atPath: backupURL(state).path) else {
            throw ToolError.message("No previous settings were saved by this app. You can choose a save location with ⇧⌘5 → Options.")
        }
        let data = try Data(contentsOf: backupURL(state))
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]], keys.allSatisfy({ values[$0]?["present"] is Bool }) else {
            throw ToolError.message("The settings backup could not be read. Choose a save location with ⇧⌘5 → Options.")
        }
        for key in keys {
            let entry = values[key]!
            CFPreferencesSetValue(key as CFString, entry["present"] as? Bool == true ? entry["value"] as CFPropertyList? : nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        try synchronize()
        try FileManager.default.removeItem(at: backupURL(state))
    }
    static func write(_ values: [String: Any]) throws {
        for (key, value) in values {
            CFPreferencesSetValue(key as CFString, value as CFPropertyList, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        try synchronize()
    }
    static func synchronize() throws {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw ToolError.message("macOS could not save screenshot settings. Press ⇧⌘5 → Options → Other Location and choose Documents → Screenshot Tool → Inbox.")
        }
    }
}
