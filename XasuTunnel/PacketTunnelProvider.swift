import NetworkExtension
import SystemConfiguration
import Tun2SocksKit
import ByeDPIKit

// Архитектура (по образцу ByeByeDPI / Rumble):
//   Весь трафик → TUN (10.0.0.1) → hev-socks5-tunnel (Tun2SocksKit) → byedpi на IP устройства → Интернет
//
// Wi-Fi: byedpi привязывается к en0 IP (192.168.x.x) — этот диапазон исключён из TUN
// LTE:   byedpi привязывается к pdp_ip0 IP (10.x.x.x или 100.x.x.x) — тоже исключён из TUN
// При смене сети iOS вызывает startTunnel заново → byedpi перепривязывается к новому IP

private let appGroupID = "group.com.xasu.dpiswitch"

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let tunIP      = "10.0.0.1"
    private let byedpiPort: UInt16 = 10800
    private let tunMTU     = 1500

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {

        // Читаем DPI аргументы из App Group UserDefaults
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        let savedArgs = sharedDefaults?.string(forKey: "xasu_combinedArgs") ?? ""
        let cmdArgs = savedArgs.components(separatedBy: " ").filter { !$0.isEmpty }

        // Получаем IP: сначала Wi-Fi, потом LTE, потом 0.0.0.0
        let networkIP = getDeviceLocalIP()
        let socksIP   = networkIP ?? "0.0.0.0"
        NSLog("[XasuTunnel] Network IP: \(socksIP), interface: \(networkIP == nil ? "none" : detectInterface())")

        // Базовые аргументы byedpi
        var byedpiArgs: [String] = [
            "-i", socksIP,
            "-p", String(byedpiPort),
            "-b", "16384",
            "-c", "512"
        ]

        // Добавляем DPI-аргументы, пропускаем базовые ключи биндинга
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

        // YAML конфиг hev-socks5-tunnel: TUN → byedpi SOCKS5
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

        // DNS: Google + Cloudflare — напрямую (excluded от TUN)
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        // IPv4: дефолтный маршрут → весь трафик через TUN.
        // Исключения: IP самого byedpi + локальные сети + DNS (чтобы не было петли).
        let ipv4 = NEIPv4Settings(addresses: [tunIP], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]

        var excluded: [NEIPv4Route] = [
            // Локальные сети
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),   // Wi-Fi
            NEIPv4Route(destinationAddress: "10.0.0.0",    subnetMask: "255.0.0.0"),     // LTE/Private
            NEIPv4Route(destinationAddress: "172.16.0.0",  subnetMask: "255.240.0.0"),   // Private B
            NEIPv4Route(destinationAddress: "100.64.0.0",  subnetMask: "255.192.0.0"),   // CGNAT (операторы)
            // DNS серверы — прямой доступ
            NEIPv4Route(destinationAddress: "8.8.8.8",     subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4",     subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "1.1.1.1",     subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "1.0.0.1",     subnetMask: "255.255.255.255"),
        ]

        // Если получили конкретный IP — дополнительно исключаем его (для надёжности)
        if let networkIP = networkIP, networkIP != "0.0.0.0" {
            excluded.insert(
                NEIPv4Route(destinationAddress: networkIP, subnetMask: "255.255.255.255"),
                at: 0
            )
        }

        ipv4.excludedRoutes = excluded
        settings.ipv4Settings = ipv4

        setTunnelNetworkSettings(settings) { setErr in
            if let setErr = setErr {
                completionHandler(setErr)
                return
            }

            Task(priority: .high) {
                // Останавливаем предыдущую сессию byedpi если была (смена сети)
                if ByeDPI.proxyStarted { _ = ByeDPI.forceStop() }
                Socks5Tunnel.quit()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100мс

                // 1. Запускаем byedpi SOCKS5 на IP устройства
                NSLog("[XasuTunnel] Starting byedpi on \(socksIP):\(self.byedpiPort)")
                if let startErr = await ByeDPI.start(args: byedpiArgs) {
                    NSLog("[XasuTunnel] byedpi failed: \(startErr)")
                    completionHandler(startErr)
                    return
                }
                NSLog("[XasuTunnel] byedpi started OK")

                // 2. Запускаем Tun2Socks в фоне (блокирующий вызов до quit())
                Socks5Tunnel.run(withConfig: .string(content: tun2socksYAML)) { code in
                    NSLog("[XasuTunnel] Tun2Socks exited with code: \(code)")
                }

                // Даём 400мс на инициализацию hev-socks5-tunnel
                try? await Task.sleep(nanoseconds: 400_000_000)
                NSLog("[XasuTunnel] Tunnel ready on \(socksIP):\(self.byedpiPort)")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[XasuTunnel] Stop tunnel, reason: \(reason.rawValue)")
        Socks5Tunnel.quit()
        if ByeDPI.proxyStarted { _ = ByeDPI.forceStop() }
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    // MARK: - IP Detection

    // Определяем тип активного интерфейса
    private func detectInterface() -> String {
        var ctlInfo = sockaddr_in()
        ctlInfo.sin_len = UInt8(MemoryLayout.size(ofValue: ctlInfo))
        ctlInfo.sin_family = sa_family_t(AF_INET)
        guard let ref = withUnsafePointer(to: &ctlInfo, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return "none" }
        var flags: SCNetworkReachabilityFlags = []
        SCNetworkReachabilityGetFlags(ref, &flags)
        if flags.contains(.isWWAN) { return "wwan/LTE" }
        if flags.contains(.reachable) { return "wifi" }
        return "none"
    }

    // Получаем реальный IP: Wi-Fi (en0) → LTE (pdp_ip0) → nil
    private func getDeviceLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var wifiIP:    String? = nil
        var cellularIP: String? = nil

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.ifa_name)

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.ifa_addr,
                        socklen_t(iface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname)
            guard !ip.isEmpty && ip != "0.0.0.0" else { continue }

            if name == "en0" || (name.hasPrefix("en") && wifiIP == nil) {
                wifiIP = ip
            } else if name.hasPrefix("pdp_ip") && cellularIP == nil {
                cellularIP = ip
            }
        }

        // Приоритет: Wi-Fi → LTE
        return wifiIP ?? cellularIP
    }
}
