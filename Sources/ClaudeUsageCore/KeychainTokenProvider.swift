import Foundation

public struct KeychainTokenProvider {
    public init() {}

    private struct Credentials: Decodable {
        struct OAuth: Decodable { let accessToken: String }
        let claudeAiOauth: OAuth
    }

    /// Reine, testbare JSON-Parsing-Funktion.
    public static func parseToken(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let creds = try? decoder.decode(Credentials.self, from: data) else {
            throw UsageError.noToken
        }
        return creds.claudeAiOauth.accessToken
    }

    /// Mappt Exit-Codes des `security`-CLI: 44 = Item nicht gefunden,
    /// 51 = Zugriff verweigert (errSecAuthFailed), 128 = Dialog abgebrochen.
    public static func error(forExitCode code: Int32) -> UsageError {
        switch code {
        case 51, 128: return .keychainDenied
        default:      return .noToken
        }
    }

    /// Liest den Token via `security`-CLI aus dem Login-Keychain.
    public func currentToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            throw UsageError.keychainDenied
        }
        // Blockiert bewusst diesen einen Thread (beim Erstlauf bis der Nutzer den
        // Keychain-Dialog beantwortet): refresh() läuft dank isFetching-Guard nie
        // parallel, der Main-Actor ist nicht betroffen.
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw Self.error(forExitCode: process.terminationStatus)
        }
        guard !data.isEmpty else { throw UsageError.noToken }
        return try Self.parseToken(from: data)
    }
}
