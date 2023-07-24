import Bolt

extension Connection {
    func request(_ request: Request) async throws -> [Response]? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                guard let promise = try self.request(request) else {
                    continuation.resume(returning: nil)
                    return
                }

                promise.whenSuccess { responses in
                    continuation.resume(returning: responses)
                }

                promise.whenFailure { error in
                    continuation.resume(throwing: error)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
