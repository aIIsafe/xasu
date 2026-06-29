import Foundation

// Генерирует .mobileconfig файл с IKEv2 VPN конфигурацией.
// Не требует никаких entitlements — iOS сам устанавливает профиль через Safari.
// Работает на Wi-Fi + LTE, в фоне, с автоподключением.

struct MobileConfigGenerator {

    struct VPNConfig {
        var serverAddress: String   // IP или домен VPS
        var remoteID: String        // Remote ID (обычно = serverAddress)
        var username: String        // EAP логин
        var password: String        // EAP пароль
        var profileName: String     = "Xasu DPI Bypass"
        var autoConnect: Bool       = true // OnDemand: подключаться автоматически
    }

    static func generate(config: VPNConfig) -> Data {
        let profileUUID   = UUID().uuidString.uppercased()
        let vpnPayloadUUID = UUID().uuidString.uppercased()

        let onDemandXML: String
        if config.autoConnect {
            onDemandXML = """
                    <key>OnDemandEnabled</key>
                    <integer>1</integer>
                    <key>OnDemandRules</key>
                    <array>
                        <dict>
                            <key>Action</key>
                            <string>Connect</string>
                        </dict>
                    </array>
"""
        } else {
            onDemandXML = """
                    <key>OnDemandEnabled</key>
                    <integer>0</integer>
"""
        }

        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadDisplayName</key>
    <string>\(config.profileName)</string>
    <key>PayloadDescription</key>
    <string>IKEv2 VPN — DPI bypass via \(config.serverAddress)</string>
    <key>PayloadIdentifier</key>
    <string>com.xasu.vpn.\(profileUUID.prefix(8).lowercased())</string>
    <key>PayloadOrganization</key>
    <string>Xasu</string>
    <key>PayloadUUID</key>
    <string>\(profileUUID)</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.vpn.managed</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.xasu.vpn.managed.\(vpnPayloadUUID.prefix(8).lowercased())</string>
            <key>PayloadUUID</key>
            <string>\(vpnPayloadUUID)</string>
            <key>PayloadDisplayName</key>
            <string>\(config.profileName)</string>
            <key>UserDefinedName</key>
            <string>\(config.profileName)</string>
            <key>VPNType</key>
            <string>IKEv2</string>
            <key>IKEv2</key>
            <dict>
                <key>RemoteAddress</key>
                <string>\(config.serverAddress)</string>
                <key>RemoteIdentifier</key>
                <string>\(config.remoteID.isEmpty ? config.serverAddress : config.remoteID)</string>
                <key>LocalIdentifier</key>
                <string>\(config.username)</string>

                <!-- EAP (логин + пароль) -->
                <key>AuthenticationMethod</key>
                <string>None</string>
                <key>ExtendedAuthEnabled</key>
                <integer>1</integer>
                <key>AuthName</key>
                <string>\(config.username)</string>
                <key>AuthPassword</key>
                <string>\(config.password)</string>

                <!-- Алгоритмы шифрования — совместимы со strongSwan/Libreswan -->
                <key>IKESecurityAssociationParameters</key>
                <dict>
                    <key>EncryptionAlgorithm</key>
                    <string>AES-256-GCM</string>
                    <key>IntegrityAlgorithm</key>
                    <string>SHA2-256</string>
                    <key>DiffieHellmanGroup</key>
                    <integer>14</integer>
                </dict>
                <key>ChildSecurityAssociationParameters</key>
                <dict>
                    <key>EncryptionAlgorithm</key>
                    <string>AES-256-GCM</string>
                    <key>IntegrityAlgorithm</key>
                    <string>SHA2-256</string>
                    <key>DiffieHellmanGroup</key>
                    <integer>14</integer>
                </dict>

                <!-- Dead Peer Detection -->
                <key>DeadPeerDetectionRate</key>
                <string>Medium</string>
                <!-- Переподключение при смене сети (Wi-Fi ↔ LTE) -->
                <key>DisableMOBIKE</key>
                <integer>0</integer>
                <!-- Редиректы разрешены -->
                <key>DisableRedirect</key>
                <integer>0</integer>
                <!-- Использовать IPv4 и IPv6 -->
                <key>EnablePFS</key>
                <integer>1</integer>
\(onDemandXML)
            </dict>
        </dict>
    </array>
</dict>
</plist>
"""
        return Data(xml.utf8)
    }

    // Сохраняем .mobileconfig в temp-файл и возвращаем URL для Share Sheet
    static func saveToTemp(config: VPNConfig) -> URL? {
        let data = generate(config: config)
        let fileName = "XasuVPN.mobileconfig"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
