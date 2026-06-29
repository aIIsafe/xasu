import Foundation

// Генерирует .mobileconfig с зашифрованным DNS (DoH/DoT).
// Профиль устанавливается вручную через Safari без энтайтлментов и без supervision.
// Ключевое: "When installed manually, this setting also applies to cellular networks" (Apple Docs).
// Работает на iOS 14+ на Wi-Fi И LTE без VPS и без платного Apple Developer.

struct DNSProfileGenerator {

    enum Provider: String, CaseIterable {
        case comss      = "Comss (Россия, анти-РКН)"
        case adguard    = "AdGuard DNS"
        case cloudflare = "Cloudflare 1.1.1.1"
        case google     = "Google 8.8.8.8"

        var displayName: String { rawValue }

        var dohURL: String {
            switch self {
            case .comss:      return "https://dns.comss.one/dns-query"
            case .adguard:    return "https://dns.adguard-dns.com/dns-query"
            case .cloudflare: return "https://1.1.1.1/dns-query"
            case .google:     return "https://dns.google/dns-query"
            }
        }

        var serverAddresses: [String] {
            switch self {
            case .comss:      return ["83.220.169.155", "195.133.25.16"]
            case .adguard:    return ["94.140.14.14", "94.140.14.15"]
            case .cloudflare: return ["1.1.1.1", "1.0.0.1"]
            case .google:     return ["8.8.8.8", "8.8.4.4"]
            }
        }
    }

    static func generate(provider: Provider) -> Data {
        let uuid     = UUID().uuidString.uppercased()
        let payUUID  = UUID().uuidString.uppercased()

        let serverAddressesXML = provider.serverAddresses
            .map { "                    <string>\($0)</string>" }
            .joined(separator: "\n")

        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadDisplayName</key>
    <string>Xasu DNS — \(provider.displayName)</string>
    <key>PayloadDescription</key>
    <string>Зашифрованный DNS (DoH). Работает на Wi-Fi и LTE. Обходит DNS-блокировки РКН.</string>
    <key>PayloadIdentifier</key>
    <string>com.xasu.dns.\(uuid.prefix(8).lowercased())</string>
    <key>PayloadOrganization</key>
    <string>Xasu</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadUUID</key>
    <string>\(uuid)</string>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.dnsSettings.managed</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.xasu.dns.settings.\(payUUID.prefix(8).lowercased())</string>
            <key>PayloadUUID</key>
            <string>\(payUUID)</string>
            <key>PayloadDisplayName</key>
            <string>Xasu DNS</string>
            <key>DNSSettings</key>
            <dict>
                <key>DNSProtocol</key>
                <string>HTTPS</string>
                <key>ServerURL</key>
                <string>\(provider.dohURL)</string>
                <key>ServerAddresses</key>
                <array>
\(serverAddressesXML)
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
"""
        return Data(xml.utf8)
    }

    static func saveToTemp(provider: Provider) -> URL? {
        let data     = generate(provider: provider)
        let fileName = "XasuDNS-\(provider.rawValue.components(separatedBy: " ").first ?? "dns").mobileconfig"
        let url      = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
