import Foundation

// MARK: - Shared App Group (main app ↔ XasuTunnel extension)
let xasuAppGroup = "group.com.xasu.dpiswitch"

enum XasuKeys {
    static let enabledPresetIDs = "xasu_enabledPresetIDs"
    static let combinedArgs     = "xasu_combinedArgs"
}

extension UserDefaults {
    static var shared: UserDefaults {
        UserDefaults(suiteName: xasuAppGroup) ?? .standard
    }

    var enabledPresetIDs: [String] {
        get { array(forKey: XasuKeys.enabledPresetIDs) as? [String] ?? [] }
        set { set(newValue, forKey: XasuKeys.enabledPresetIDs) }
    }

    var combinedArgs: String {
        get { string(forKey: XasuKeys.combinedArgs) ?? "" }
        set { set(newValue, forKey: XasuKeys.combinedArgs) }
    }
}
