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

    // Запуск через SBDConfig:
    // - Автоматически добавляет -i, -p, -b, -c
    // - Фильтрует iOS-несовместимые флаги (--fake-sni, --fake, --disorder, --oob, --ttl...)
    // - Принимает ТОЛЬКО dpi-evasion аргументы (без --ip/--port)
    func start(dpiArgs: [String], completion: @escaping (ProxyStartResult) -> Void) {
        // Полная остановка предыдущего экземпляра
        _ = ByeDPI.forceStop()
        _ = ByeDPI.stop()

        // Строим конфиг через SBDConfig — он сам валидирует и фильтрует
        let config = SBDConfig(
            listenIP:    SBDConfig.defaultListenIP,
            listenPort:  SBDConfig.defaultListenPort,
            bufSize:     SBDConfig.defaultBufSize,
            maxConn:     SBDConfig.defaultMaxConn,
            commandArgs: dpiArgs
        )
        let finalArgs = config.args  // уже отвалидированные аргументы

        // Пауза для освобождения порта
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.6) {
            self.attemptStart(args: finalArgs, retriesLeft: 2, completion: completion)
        }
    }

    private func attemptStart(args: [String], retriesLeft: Int, completion: @escaping (ProxyStartResult) -> Void) {
        var callbackFired = false

        ByeDPI.start(args: args) { [weak self] error in
            guard !callbackFired else { return }
            var errCode: Int? = nil
            if case .startError(let code) = error { errCode = code }

            if errCode == -2 && retriesLeft > 0 {
                _ = ByeDPI.forceStop()
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                    self?.attemptStart(args: args, retriesLeft: retriesLeft - 1, completion: completion)
                }
            } else {
                callbackFired = true
                DispatchQueue.main.async { completion(.failure(error.errorDescription)) }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard !callbackFired else { return }
            if ByeDPI.proxyStarted {
                callbackFired = true
                completion(.success)
            }
        }
    }

    func stop() {
        _ = ByeDPI.forceStop()
        _ = ByeDPI.stop()
    }
}
