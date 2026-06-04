import Foundation
import SwiftUI
import Combine

// MARK: - Language Manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var currentLanguage: String

    private init() {
        let saved = UserDefaults.standard.string(forKey: StorageKeys.appLanguage) ?? "ru"
        self.currentLanguage = saved
        Bundle.setLanguage(saved)
    }

    func setLanguage(_ code: String) {
        guard code != currentLanguage else { return }
        currentLanguage = code
        UserDefaults.standard.set(code, forKey: StorageKeys.appLanguage)
        Bundle.setLanguage(code)
        // Уведомляем все подписчики что язык изменился
        objectWillChange.send()
        NotificationCenter.default.post(name: .languageChanged, object: code)
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - Bundle swizzle для runtime смены языка

private var bundleKey = "VerbumLanguageBundle"

final class LanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        // Маппинг кодов приложения → коды iOS локалей
        let iOSCode: String
        switch language {
        case "en": iOSCode = "en"
        case "uk": iOSCode = "uk"
        default:   iOSCode = "ru"
        }

        defer {
            object_setClass(Bundle.main, LanguageBundle.self)
        }

        guard let path = Bundle.main.path(forResource: iOSCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Если языковой пакет не найден — сбрасываем на основной
            objc_setAssociatedObject(
                Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return
        }
        objc_setAssociatedObject(
            Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

// MARK: - Удобный доступ к строкам

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
    if args.isEmpty { return format }
    return String(format: format, arguments: args)
}
