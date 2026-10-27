import Foundation
import Security

final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
final class MacClient {
    let connection: Connection
    private let session: URLSession
    init(_ connection: Connection, configuration: URLSessionConfiguration = .ephemeral) {
        self.connection = connection
        let config = configuration
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 45
        config.httpCookieStorage = nil; config.urlCache = nil
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    func request(_ path: String, body: Data? = nil, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: connection.baseURL.appendingPathComponent(path))
        request.setValue("Bearer " + connection.token, forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let body { request.httpMethod = "POST"; request.httpBody = body }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.message("The Mac did not respond.") }
        if http.statusCode == 401 { throw AppError.message("Pair again using Connect iPad on your Mac.") }
        guard (200...299).contains(http.statusCode) else {
            throw AppError.message((try? JSONDecoder().decode(APIError.self, from: data).error) ?? "The Mac could not complete that request. Your drawing is kept on this iPad.")
        }
        guard data.count <= 40 * 1024 * 1024 else { throw AppError.message("That image is too large. Capture a smaller area on the Mac.") }
        return data
    }
    func library() async throws -> [Capture] {
        let result = try JSONDecoder().decode(LibraryResponse.self, from: await request("api/library"))
        guard result.captures.count <= 100, Set(result.captures.map(\.id)).count == result.captures.count else { throw AppError.message("The Mac returned an invalid screenshot list.") }
        return result.captures
    }
    func image(_ capture: Capture) async throws -> Data {
        guard capture.valid else { throw AppError.message("This screenshot is too large to draw on. Capture a smaller area.") }
        return try await request("api/image/" + capture.id)
    }
    func save(_ data: Data, capture: Capture, id: String) async throws -> SaveReceipt {
        try JSONDecoder().decode(SaveReceipt.self, from: await request("api/save", body: data, headers: ["Content-Type":"image/png", "X-Capture-ID":capture.id, "X-Submission-ID":id]))
    }
    func status() async throws -> MacStatus { try JSONDecoder().decode(MacStatus.self, from: await request("api/status")) }
}

enum ConnectionVault {
    private static let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"ScreenshotTool.Native.Connection", kSecAttrAccount as String:"paired-mac"]
    static func read() -> Connection? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Connection.self, from: data)
    }
    static func write(_ connection: Connection) throws {
        let data = try JSONEncoder().encode(connection)
        let attrs: [String: Any] = [kSecValueData as String:data, kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var result = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if result == errSecItemNotFound { result = SecItemAdd(query.merging(attrs) { _, new in new } as CFDictionary, nil) }
        guard result == errSecSuccess else { throw AppError.message("Could not remember this Mac securely. Try pairing again.") }
    }
}
