import UIKit

enum ThemeApplier {
    static func applyTheme(useSystemTheme: Bool, isDarkMode: Bool, animated: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let style: UIUserInterfaceStyle = useSystemTheme ? .unspecified : (isDarkMode ? .dark : .light)
        
        if window.overrideUserInterfaceStyle == style { return }
        
        if animated {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                window.overrideUserInterfaceStyle = style
            }, completion: nil)
        } else {
            UIView.performWithoutAnimation {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
