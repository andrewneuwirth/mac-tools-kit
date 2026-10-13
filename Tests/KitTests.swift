import Foundation
import Testing
@testable import MacToolsKit

@Test func usageThresholds() {
    #expect(MTStatus.forUsage(49.9) == nil)
    #expect(MTStatus.forUsage(50) == .warn)
    #expect(MTStatus.forUsage(80) == .bad)
}

@Test func readsUsageRingsFile() throws {
    // A real usage.json as Usage Rings wrote it.
    let json = #"{"claude":{"failed":false,"short":{"percent":34,"resetsAt":1791243599.728},"stale":false,"long":{"percent":12,"resetsAt":1791817199.728}},"chatgpt":{"failed":false,"stale":false,"long":{"percent":13,"resetsAt":1791776836},"note":"Pro"},"updated":1791231663.769757}"#
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("usage-test.json")
    try Data(json.utf8).write(to: url)
    let snap = try #require(UsageSnapshot.read(from: url))
    #expect(snap.claude?.primary?.percent == 34)
    #expect(snap.claude?.secondary?.percent == 12)
    #expect(snap.chatgpt?.primary?.percent == 13)
    #expect(snap.chatgpt?.secondary == nil)
}
