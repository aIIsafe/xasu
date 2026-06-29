import Foundation
import SwByeDPI

enum ProxyStartResult {
    case success
    case failure(String)
}

final class ByeDPIService {

    static let shared = ByeDPIService()
    private init() {}

    var isRunning: Bool { ByeDPI.proxyStarted }
    var proxyAddress: String { "127.0.0.1:10800" }

    private(set) var activeArgs: [String] = []

    func start(args: [String], completion: @escaping (ProxyStartResult) -> Void) {
        if isRunning { _ = ByeDPI.stop() }
        activeArgs = args

        var callbackFired = false

        ByeDPI.start(args: args) { [weak self] error in
            guard !callbackFired else { return }
            callbackFired = true
            self?.activeArgs = []
            DispatchQueue.main.async {
                completion(.failure(error.errorDescription))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard !callbackFired else { return }
            guard let self else { return }
            if self.isRunning {
                callbackFired = true
                completion(.success)
            }
        }
    }

    @discardableResult
    func stop() -> Bool {
        activeArgs = []
        return ByeDPI.stop() == 0
    }
}
