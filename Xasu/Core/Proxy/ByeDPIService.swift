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

    private let startDelay: TimeInterval = 0.8   // ждём освобождения порта
    private let maxRetries = 3

    func start(args: [String], completion: @escaping (ProxyStartResult) -> Void) {
        // Всегда останавливаем предыдущий экземпляр
        if isRunning { _ = ByeDPI.stop() }

        // Ждём освобождения порта, затем запускаем (с retry)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + startDelay) {
            self.attemptStart(args: args, retriesLeft: self.maxRetries, completion: completion)
        }
    }

    private func attemptStart(args: [String], retriesLeft: Int, completion: @escaping (ProxyStartResult) -> Void) {
        var didCallback = false

        ByeDPI.start(args: args) { [weak self] error in
            guard !didCallback else { return }
            let msg = error.errorDescription
            // Порт занят — попробуем ещё раз
            if (msg.contains("-2") || msg.contains("address already in use")) && retriesLeft > 0 {
                _ = ByeDPI.stop()
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.8) {
                    self?.attemptStart(args: args, retriesLeft: retriesLeft - 1, completion: completion)
                }
            } else {
                didCallback = true
                DispatchQueue.main.async { completion(.failure(msg)) }
            }
        }

        // Даём 1 секунду на старт
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard !didCallback else { return }
            if ByeDPI.proxyStarted {
                didCallback = true
                completion(.success)
            }
        }
    }

    @discardableResult
    func stop() -> Bool {
        let result = ByeDPI.stop()
        return result == 0
    }
}
