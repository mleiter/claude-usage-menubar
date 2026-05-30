import Foundation

public struct UsageClient: Sendable {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public static func makeRequest(token: String) -> URLRequest {
        var request = URLRequest(url: ClaudeUsageCore.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return request
    }

    /// Liefert nil bei Erfolg (2xx), sonst den passenden Fehler.
    public static func error(forStatus status: Int) -> UsageError? {
        switch status {
        case 200...299: return nil
        case 401:       return .tokenExpired
        case 429:       return .rateLimited
        default:        return .network("HTTP \(status)")
        }
    }

    public func fetch(token: String) async throws -> Usage {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: Self.makeRequest(token: token))
        } catch {
            throw UsageError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = Self.error(forStatus: status) { throw error }
        do {
            return try JSONDecoder.usageDecoder().decode(Usage.self, from: data)
        } catch {
            throw UsageError.decoding
        }
    }
}
