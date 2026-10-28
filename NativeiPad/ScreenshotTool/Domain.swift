import Foundation
import CryptoKit

struct Capture: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let width: Int
    let height: Int
    let modified: Double
    var saved: Bool
    static func oldestFirst(_ lhs: Capture, _ rhs: Capture) -> Bool {
        lhs.modified == rhs.modified ? lhs.id < rhs.id : lhs.modified < rhs.modified
    }
    var valid: Bool { id.count == 24 && id.allSatisfy { $0.isHexDigit } && width > 0 && height > 0 && width <= 16000 && height <= 16000 && width * height <= 16000000 }
}
struct LibrarySession: Codable, Equatable { let id: String; let startedAt: Double }
struct LibraryResponse: Decodable {
    let captures: [Capture]
    let session: LibrarySession?
    let supportsSessions: Bool?
}
struct CleanupPreview: Decodable, Equatable {
    let token: String
    let captureCount: Int
    let fileCount: Int
    let byteCount: Int
    var sizeDescription: String { ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file) }
}
struct CleanupReceipt: Decodable { let movedFiles: Int; let movedBytes: Int; let movedCaptureIDs: [String]? }
struct MacStatus: Decodable { let lastCopied: String? }
struct SaveReceipt: Decodable { let id: String; let filename: String }
struct APIError: Decodable { let error: String }

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

struct Connection: Codable, Equatable {
    let baseURL: URL
    let token: String
    var namespace: String { SHA256.hash(data: Data(token.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined() }
    var displayName: String { baseURL.host ?? "Your Mac" }
    static func parse(_ text: String) throws -> Connection {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == "http", let host = parts.host, isLocalHost(host),
              parts.user == nil, parts.password == nil, parts.query == nil,
              parts.path.isEmpty || parts.path == "/", let port = parts.port, (1...65535).contains(port),
              let fragment = parts.fragment,
              let token = URLComponents(string: "?" + fragment)?.queryItems?.first(where: { $0.name == "pair" })?.value,
              (16...128).contains(token.count), token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        else { throw AppError.message("Scan the Connect iPad QR code in Ludwig's Annotated Screenshots on your Mac.") }
        var base = URLComponents(); base.scheme = "http"; base.host = host; base.port = port
        guard let url = base.url else { throw AppError.message("The Mac address is invalid.") }
        return Connection(baseURL: url, token: token)
    }
    static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") { return true }
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        return octets[0] == 10 || octets[0] == 127 || (octets[0] == 192 && octets[1] == 168) || (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 169 && octets[1] == 254)
    }
}

struct CaptureQueue: Codable {
    var ids: [String] = []
    mutating func merge(_ captures: [Capture], locallySaved: Set<String> = []) {
        let all = Dictionary(uniqueKeysWithValues: captures.map { ($0.id, $0) })
        ids = ids.filter { all[$0] != nil }
        let added = captures.filter { !$0.saved && !locallySaved.contains($0.id) && !ids.contains($0.id) }.sorted { $0.modified == $1.modified ? $0.id < $1.id : $0.modified < $1.modified }
        if !added.isEmpty && !ids.contains(where: { all[$0]?.saved == false && !locallySaved.contains($0) }) { ids = [] }
        ids += added.map(\.id)
    }
    func pending(_ captures: [Capture], locallySaved: Set<String> = []) -> [Capture] {
        let all = Dictionary(uniqueKeysWithValues: captures.map { ($0.id, $0) })
        return ids.compactMap { all[$0] }.filter { !$0.saved && !locallySaved.contains($0.id) }
    }
    func position(_ id: String) -> String { ids.firstIndex(of: id).map { "\($0 + 1) of \(ids.count)" } ?? "Previous screenshot" }
}

// A browsing session has fixed rows: polling can update the queue without moving this list.
struct CaptureBrowserSnapshot: Identifiable {
    let id = UUID()
    let captures: [Capture]
    let selectedID: String?
    let draftIDs: Set<String>
}
