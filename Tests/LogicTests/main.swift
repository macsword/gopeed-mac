// Foundation-only checks for TaskStats decoding and CompletionTracker.
// Runs on macOS or Linux: Tests/run-logic-tests.sh
import Foundation

struct Envelope<T: Decodable>: Decodable { let code: Int; let data: T? }

var failures = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String, line: Int = #line) {
    if cond() { print("ok   \(msg)") } else { failures += 1; print("FAIL \(msg) (line \(line))") }
}

let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
func load(_ name: String) throws -> TaskStats? {
    let data = try Data(contentsOf: fixtures.appendingPathComponent(name))
    return try JSONDecoder().decode(Envelope<TaskStats>.self, from: data).data
}

do {
    // stats-http.json was produced by marshalling Gopeed's own fetcher.Stats /
    // http.Stats types through rest/model.NewOkResult (upstream 8ef3b63).
    let http = try load("stats-http.json")
    let c = http?.connections ?? []
    check(c.count == 4, "nested snapshot.connections decoded (4)")
    if c.count == 4 {
        check(c[0].state == .completed && c[0].fraction == 1, "completed connection")
        check(c[1].state == .active && c[1].fraction == 0.25, "active connection fraction 0.25")
        check(c[2].fraction == 1 && c[2].state == .active, "over-share clamps to 1 but stays active")
        check(c[3].state == .failed && c[3].retryTimes == 3, "failed connection with retries")
    }

    let nullStats = try load("stats-null.json")
    check(nullStats == nil, "data:null decodes to nil stats")

    let other = try load("stats-non-http.json")
    check(other != nil && other?.connections == nil, "non-HTTP snapshot -> stats without connections")

    let legacy = try load("stats-legacy-flat.json")
    check(legacy?.connections?.count == 1, "legacy flat shape still decodes")

    let unknownSize = StatConnection(downloaded: 5, total: 0, completed: false, failed: false, retryTimes: nil)
    check(unknownSize.fraction == nil, "unknown size -> no fraction")
} catch {
    failures += 1
    print("FAIL decoding threw: \(error)")
}

var tracker = CompletionTracker()
check(tracker.newlyCompleted([("a", true), ("b", false)]).isEmpty, "first poll is baseline (historic done ignored)")
check(tracker.newlyCompleted([("a", true), ("b", false)]).isEmpty, "no change -> nothing")
check(tracker.newlyCompleted([("a", true), ("b", true)]) == ["b"], "b finishes -> notified once")
check(tracker.newlyCompleted([("a", true), ("b", true)]).isEmpty, "b not re-notified")
check(tracker.newlyCompleted([("a", true), ("b", false)]).isEmpty, "b restarted")
check(tracker.newlyCompleted([("a", true), ("b", true), ("c", true)]) == ["b", "c"], "re-finish, and task added already done")
var fresh = CompletionTracker()
check(fresh.newlyCompleted([]).isEmpty, "empty baseline")
check(fresh.newlyCompleted([("x", true)]) == ["x"], "task finishing after empty baseline")

if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("all logic tests passed")
