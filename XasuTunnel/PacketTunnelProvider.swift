import NetworkExtension
import SystemConfiguration
import Tun2SocksKit
import ByeDPIKit

// Архитектура (по образцу ByeByeDPI / Rumble):
//   Весь трафик → TUN (10.0.0.1) → hev-socks5-tunnel (Tun2SocksKit) → byedpi на реальном IP → Интернет
//
// Ключ: byedpi слушает на реальном IP устройства (Wi-Fi/LTE), а не 127.0.0.1.
// Иначе TUN перехватит пакеты byedpi и создаст бесконечную петлю.

private let appGroupID = "group.com.xasu.dpiswitch"

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let tunIP      = "10.0.0.1"
    private let byedpiPort: UInt16 = 10800
    private let tunMTU     = 1500

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {

        // Читаем сохранённые аргументы byedpi из App Group UserDefaults
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        let savedArgs = sharedDefaults?.string(forKey: "xasu_combinedArgs") ?? ""
        let cmdArgs = savedArgs.isEmpty ? [] : savedArgs
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        // Получаем реальный IP устройства (Wi-Fi или LTE) для биндинга byedpi
        let socksIP = getDeviceLocalIP() ?? "0.0.0.0"

        // Базовые аргументы byedpi (биндинг + порт)
        var byedpiArgs: [String] = [
            "-i", socksIP,
            "-p", String(byedpiPort),
            "-b", "16384",
            "-c", "512"
        ]

        // Добавляем DPI-аргументы, исключая дублирующие ключи биндинга
        let skipKeys: Set<String> = ["-i", "--ip", "-p", "--port", "-b", "--bufSize", "-c", "--max-conn"]
        var idx = 0
        while idx < cmdArgs.count {
            if skipKeys.contains(cmdArgs[idx]) {
                idx += 2
            } else {
                byedpiArgs.append(cmdArgs[idx])
                idx += 1
            }
        }

        // YAML конфиг hev-socks5-tunnel (Tun2SocksKit)
        let tun2socksYAML = """
tunnel:
  mtu: \(tunMTU)

socks5:
  port: \(byedpiPort)
  address: \(socksIP)
  udp: 'udp'

misc:
  task-stack-size: 24576
  tcp-buffer-size: 4096
  max-session-count: 1200
"""

        // Настройки TUN-интерфейса
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: socksIP)
        settings.mtu = NSNumber(value: tunMTU)

        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        let ipv4 = NEIPv4Settings(addresses: [tunIP], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = [
            // Адрес byedpi — не перехватываем (избегаем петли)
            NEIPv4Route(destinationAddress: socksIP,       subnetMask: "255.255.255.255"),
            // Локальные сети
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "10.0.0.0",    subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0",  subnetMask: "255.240.0.0"),
            // DNS серверы — прямой доступ
            NEIPv4Route(destinationAddress: "8.8.8.8",     subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4",     subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "1.1.1.1",     subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "1.0.0.1",     subnetMask: "255.255.255.255"),
        ]
        settings.ipv4Settings = ipv4

        setTunnelNetworkSettings(settings) { setErr in
            if let setErr = setErr {
                completionHandler(setErr)
                return
            }

            Task(priority: .high) {
                // 1. Запускаем byedpi SOCKS5
                if let startErr = await ByeDPI.start(args: byedpiArgs) {
                    completionHandler(startErr)
                    return
                }

                // 2. Запускаем Tun2Socks в фоне — блокирующий вызов до quit()
                Socks5Tunnel.run(withConfig: .string(content: tun2socksYAML)) { code in
                    // Вызывается когда туннель остановился
                    if code != 0 {
                        NSLog("[XasuTunnel] Tun2Socks stopped with code: \(code)")
                    }
                }

                // Даём 300мс на инициализацию тунелля, затем сигнализируем об успехе
                try? await Task.sleep(nanoseconds: 300_000_000)
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Socks5Tunnel.quit()
        if ByeDPI.proxyStarted { _ = ByeDPI.forceStop() }
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    // Реальный IP Wi-Fi (en0) или LTE (pdp_ip0)
    private func getDeviceLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.ifa_addr,
                        socklen_t(iface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname)
            if !ip.isEmpty && ip != "0.0.0.0" { return ip }
        }
        return nil
    }
}
