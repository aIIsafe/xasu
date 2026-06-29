import Foundation
import Network
import Observation

/// Локальный HTTP-сервер, отдающий PAC-скрипт.
/// PAC (Proxy Auto-Config) — единственный способ направить трафик iOS через SOCKS5
/// без VPN entitlement. iOS поддерживает SOCKS в PAC: "SOCKS 127.0.0.1:10800".
@Observable
final class PACServer {

    static let shared = PACServer()
    private init() {}

    private(set) var isRunning = false

    let tcpPort: UInt16 = 8085
    var pacURL: String { "http://127.0.0.1:\(tcpPort)/proxy.pac" }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "xasu.pac", qos: .utility)

    // ── PAC-скрипт ───────────────────────────────────────────────────────────
    // Возвращает "SOCKS 127.0.0.1:10800" для всего внешнего трафика.
    // Локальные адреса обходим напрямую.
    var pacScript: String {
        """
        function FindProxyForURL(url, host) {
            if (isPlainHostName(host)) return "DIRECT";
            if (shExpMatch(host, "localhost")) return "DIRECT";
            if (isInNet(host, "127.0.0.0", "255.0.0.0")) return "DIRECT";
            if (isInNet(host, "192.168.0.0", "255.255.0.0")) return "DIRECT";
            if (isInNet(host, "10.0.0.0", "255.0.0.0")) return "DIRECT";
            return "SOCKS 127.0.0.1:10800";
        }
        """
    }

    // ── Запуск ────────────────────────────────────────────────────────────────
    func start() {
        guard !isRunning else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let port = NWEndpoint.Port(rawValue: tcpPort)!
            listener = try NWListener(using: params, on: port)
        } catch {
            AppLogger.shared.log("PAC server init error: \(error)", level: .error)
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                AppLogger.shared.log("PAC server ready: \(self?.pacURL ?? "")", level: .success)
            case .failed(let e):
                AppLogger.shared.log("PAC server failed: \(e)", level: .error)
                self?.isRunning = false
            default: break
            }
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // ── Обработка HTTP запроса ────────────────────────────────────────────────
    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, _ in
            guard let self else { return }
            let body = self.pacScript.data(using: .utf8) ?? Data()
            let header = """
            HTTP/1.1 200 OK\r
            Content-Type: application/x-ns-proxy-autoconfig\r
            Content-Length: \(body.count)\r
            Connection: close\r
            \r

            """
            var response = (header.data(using: .utf8) ?? Data())
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
