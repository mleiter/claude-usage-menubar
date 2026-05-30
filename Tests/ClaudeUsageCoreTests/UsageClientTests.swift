import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func buildsAuthorizedRequest() {
    let request = UsageClient.makeRequest(token: "sk-ant-oat01-TEST")
    #expect(request.url == ClaudeUsageCore.endpoint)
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-ant-oat01-TEST")
    #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
}

@Test func mapsStatusCodesToErrors() {
    #expect(UsageClient.error(forStatus: 401) == .tokenExpired)
    #expect(UsageClient.error(forStatus: 429) == .rateLimited)
    #expect(UsageClient.error(forStatus: 500) == .network("HTTP 500"))
    #expect(UsageClient.error(forStatus: 200) == nil)
}
