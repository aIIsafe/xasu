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

    func start(args: [String], completion: @escaping (ProxyStartResult) -> Void) {
        // Полная остановка — forceStop закрывает server_fd напрямую,
        // не зависая на fake SOCKS Hello. Это освобождает порт быстрее.
        _ = ByeDPI.forceStop()
        _ = ByeDPI.stop()

        // Небольшая пауза для освобождения порта ОС
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.6) {
            self.attemptStart(args: args, retriesLeft: 2, completion: completion)
        }
    }

    private func attemptStart(args: [String], retriesLeft: Int, completion: @escaping (ProxyStartResult) -> Void) {
        var callbackFired = false

        ByeDPI.start(args: args) { [weak self] error in
            guard !callbackFired else { return }
            let msg = error.errorDescription

            // Извлекаем код ошибки через pattern matching
            var errCode: Int? = nil
            if case .startError(let code) = error { errCode = code }

            // -2 (порт занят / неверный аргумент) — форс-стоп и повтор
            if errCode == -2 && retriesLeft > 0 {
                _ = ByeDPI.forceStop()
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                    self?.attemptStart(args: args, retriesLeft: retriesLeft - 1, completion: completion)
                }
            } else {
                callbackFired = true
                DispatchQueue.main.async { completion(.failure(msg)) }
            }
        }

        // Проверяем успешный старт через 1.2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard !callbackFired else { return }
            if ByeDPI.proxyStarted {
                callbackFired = true
                completion(.success)
            }
            // Если не запустился и нет ошибки — ждём callback
        }
    }

    func stop() {
        _ = ByeDPI.forceStop()
        _ = ByeDPI.stop()
    }
}
