import Foundation
import Observation

@Observable
final class SettingsViewModel {

    var presets: [ServicePreset] = PresetLibrary.all

    init() {
        let enabled = UserDefaults.shared.enabledPresetIDs
        for i in presets.indices {
            presets[i].isEnabled = enabled.contains(presets[i].id)
        }
    }

    func toggle(presetID: String) {
        guard let i = presets.firstIndex(where: { $0.id == presetID }) else { return }
        presets[i].isEnabled.toggle()
        persist()
    }

    var combinedArgs: [String] {
        PresetLibrary.buildArgs(from: presets)
    }

    // Обновляет shared UserDefaults — extension читает при запуске
    private func persist() {
        let enabledIDs = presets.filter(\.isEnabled).map(\.id)
        UserDefaults.shared.enabledPresetIDs = enabledIDs
        UserDefaults.shared.combinedArgs = combinedArgs.joined(separator: " ")
    }
}
