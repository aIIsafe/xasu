import NetworkExtension
import SystemConfiguration
import Tun2SocksKit
import ByeDPIKit

// Архитектура (по образцу ByeByeDPI от mIwr/SwByeDPI):
//   TUN (10.0.0.1) → Tun2SocksKit (hev-socks5-tunnel) → byedpi на реальном IP устройства → Интернет
//
// ВАЖНО: byedpi слушает на реальном Wi-Fi/LTE IP, а не 127.0.0.1.
// Если использовать loopback, TUN перехватит пакеты byedpi в бесконечную петлю.

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let tunIP      = "10.0.0.1"
    private let byedpiPort: UInt16 = 10800
    private let tunMTU     = 1500

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {

        // Получаем DPI аргументы из options (переданы VPNManager) или App Group UserDefaults
        var rawArgs = (options?["xasuArgs"] as? String) ?? ""
        if rawArgs.isEmpty {
            rawArgs = UserDefaults.shared.combinedArgs
        }
        let cmdArgs = rawArgs.isEmpty ? [] : rawArgs.components(separatedBy: " ").filter { !$0.isEmpty }

        // Получаем реальный IP устройства (Wi-Fi или LTE) для биндинга byedpi
        let socksListenIP = getDeviceLocalIP() ?? "0.0.0.0"

        // Формируем финальные аргументы byedpi через SBDConfig (валидирует iOS-restricted флаги)
        var byedpiArgs: [String] = [
            "-i", socksListenIP,
            "-p", String(byedpiPort),
            "-b", "16384",
            "-c", "512",
            "-U"  // отключить UDP, работаем только с TCP
        ]
        // Добавляем DPI-evasion аргументы (уже провалидированы SBDConfig в SOCKS режиме)
        if !cmdArgs.isEmpty {
            // Проверяем что нет дублирующих базовых ключей
            let skipKeys: Set<String> = ["-i","--ip","-p","--port","-b","--bufSize","-c","--max-conn"]
            var i = 0
            while i < cmdArgs.count {
                if skipKeys.contains(cmdArgs[i]) {
                    i += 2
                } else {
                    byedpiArgs.append(cmdArgs[i])
                    i += 1
                }
            }
        }

        // Конфиг Tun2Socks (hev-socks5-tunnel)
        let tun2socksConfig = """
tunnel:
  mtu: \(tunMTU)

socks5:
  port: \(byedpiPort)
  address: \(socksListenIP)
  udp: 'udp'

misc:
  task-stack-size: 24576
  tcp-buffer-size: 4096
  max-session-count: 1200
"""

        // Настройки TUN интерфейса
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: socksListenIP)
        settings.mtu = NSNumber(value: tunMTU)

        // DNS: используем Google + Cloudflare
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        // IPv4: дефолтный маршрут через TUN, исключения для byedpi и DNS
        let ipv4 = NEIPv4Settings(addresses: [tunIP], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = [
            // Адрес самого byedpi — НЕ перехватываем
            NEIPv4Route(destinationAddress: socksListenIP, subnetMask: "255.255.255.255"),
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

        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                completionHandler(error)
                return
            }

            Task(priority: .high) {
                // 1. Запускаем byedpi SOCKS5 прокси
                if let startErr = await ByeDPI.start(args: byedpiArgs) {
                    completionHandler(startErr)
                    return
                }

                // 2. Запускаем Tun2Socks: перенаправляет TUN → byedpi SOCKS5
                let tun2socksResult = await Socks5Tunnel.run(
                    with: .string(content: tun2socksConfig)
                )

                if tun2socksResult == 0 {
                    completionHandler(nil)
                } else {
                    _ = ByeDPI.forceStop()
                    completionHandler(
                        NSError(domain: NEVPNErrorDomain, code: Int(tun2socksResult))
                    )
                }
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Socks5Tunnel.stop()
        if ByeDPI.proxyStarted { _ = ByeDPI.forceStop() }
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    // Получаем реальный IP адрес Wi-Fi интерфейса
    private func getDeviceLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.ifa_name)
            // en0 = Wi-Fi, pdp_ip0 = LTE
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname)
            if !ip.isEmpty && ip != "0.0.0.0" { return ip }
        }
        return nil
    }
}
