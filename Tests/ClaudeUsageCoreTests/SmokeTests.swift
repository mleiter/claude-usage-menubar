import Testing
@testable import ClaudeUsageCore

@Test func endpointIsCorrect() {
    #expect(ClaudeUsageCore.endpoint.absoluteString == "https://api.anthropic.com/api/oauth/usage")
}
