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
