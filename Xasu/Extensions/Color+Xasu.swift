import SwiftUI

extension Color {

    // MARK: - Xasu Brand Colors

    /// Фоновый цвет — глубокий космический чёрный
    static let xasuBackground = Color(red: 0.04, green: 0.03, blue: 0.09)

    /// Основной акцент — фиолетовый Xasu
    static let xasuPurple = Color(red: 0.46, green: 0.33, blue: 0.96)

    /// Активный / подключён — голубой
    static let xasuCyan = Color(red: 0.12, green: 0.90, blue: 0.78)

    /// Кнопка неактивная
    static let buttonInactive = Color(red: 0.18, green: 0.16, blue: 0.26)

    /// Кнопка активная
    static let buttonActive = xasuCyan

    // MARK: - Text

    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary  = Color.white.opacity(0.28)

    // MARK: - UI

    static let appSeparator  = Color.white.opacity(0.07)

    // MARK: - Сервисы

    static func presetAccent(for id: String) -> Color {
        switch id {
        case "youtube":   return Color(red: 0.96, green: 0.22, blue: 0.22) // YouTube Red
        case "tiktok":    return Color(red: 0.13, green: 0.84, blue: 0.88) // TikTok Cyan
        case "discord":   return Color(red: 0.35, green: 0.44, blue: 0.95) // Discord Blue
        case "instagram": return Color(red: 0.95, green: 0.38, blue: 0.52) // Instagram Pink
        default:          return xasuPurple
        }
    }
}
