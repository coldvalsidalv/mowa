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
        // Notify all subscribers that the language changed
        objectWillChange.send()
        NotificationCenter.default.post(name: .languageChanged, object: code)
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - Bundle swizzle for runtime language switching

private var bundleKey: UInt8 = 0

final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        // Map app language codes → iOS locale codes
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
            // If the language pack isn't found — fall back to the main bundle
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

// MARK: - Convenient string access

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
    if args.isEmpty { return format }
    return String(format: format, arguments: args)
}
