import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func parsesAccessTokenFromKeychainJSON() throws {
    let data = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-TEST","refreshToken":"x"}}"#
        .data(using: .utf8)!
    let token = try KeychainTokenProvider.parseToken(from: data)
    #expect(token == "sk-ant-oat01-TEST")
}

@Test func throwsNoTokenWhenMissing() {
    let data = #"{"somethingElse":{}}"#.data(using: .utf8)!
    #expect(throws: UsageError.noToken) {
        try KeychainTokenProvider.parseToken(from: data)
    }
}

@Test func mapsSecurityExitCodesToDistinctErrors() {
    #expect(KeychainTokenProvider.error(forExitCode: 44) == .noToken)         // errSecItemNotFound
    #expect(KeychainTokenProvider.error(forExitCode: 51) == .keychainDenied)  // errSecAuthFailed
    #expect(KeychainTokenProvider.error(forExitCode: 128) == .keychainDenied) // vom Nutzer abgebrochen
    #expect(KeychainTokenProvider.error(forExitCode: 1) == .noToken)
}
