#if DEBUG
import Observation

@Observable
@MainActor
final class NetworkDiagnostics {
    static let shared = NetworkDiagnostics()
    private(set) var requestCount = 0
    func recordRequest() { requestCount += 1 }
}
#endif
