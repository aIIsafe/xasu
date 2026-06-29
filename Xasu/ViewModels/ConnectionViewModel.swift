import Foundation
import Observation
import NetworkExtension

@Observable
final class ConnectionViewModel {

    private(set) var connectionState: ConnectionState = .disconnected
    var errorMessage: String?

    private let vpn = VPNManager.shared
    private let settingsVM: SettingsViewModel

    init(settingsVM: SettingsViewModel) {
        self.settingsVM = settingsVM
        syncStateFromVPN()
    }

    func toggleConnection() {
        switch connectionState {
        case .disconnected, .error:
            connect()
        case .connected:
            disconnect()
        case .connecting:
            break
        }
    }

    // MARK: - Наблюдение за статусом VPN

    func syncStateFromVPN() {
        connectionState = mapStatus(vpn.status)
    }

    func onVPNStatusChange() {
        connectionState = mapStatus(vpn.status)
    }

    // MARK: - Приватное

    private func connect() {
        connectionState = .connecting
        let args = settingsVM.combinedArgs

        Task { @MainActor in
            do {
                try await vpn.start(args: args)
            } catch {
                self.connectionState = .error(error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func disconnect() {
        vpn.stop()
        connectionState = .disconnected
    }

    private func mapStatus(_ status: NEVPNStatus) -> ConnectionState {
        switch status {
        case .connected:                       return .connected
        case .connecting, .reasserting:        return .connecting
        case .disconnecting, .disconnected:    return .disconnected
        case .invalid:                         return .error("VPN profile not found")
        @unknown default:                      return .disconnected
        }
    }
}
