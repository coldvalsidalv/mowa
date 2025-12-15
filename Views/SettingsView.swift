import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = 0
    @AppStorage("appLanguage") private var appLanguage = "ru"
    
    // Состояние для показа предупреждения
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Внешний вид")) {
                Picker("Тема оформления", selection: Binding(
                    get: { selectedTheme },
                    set: { newValue in
                        selectedTheme = newValue
                        updateTheme(newValue)
                    }
                )) {
                    Text("Системная").tag(0)
                    Text("Светлая").tag(1)
                    Text("Тёмная").tag(2)
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Язык интерфейса")) {
                Picker("Язык", selection: $appLanguage) {
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                    Text("Polski").tag("pl")
                }
            }
            
            // НОВАЯ СЕКЦИЯ: УПРАВЛЕНИЕ ДАННЫМИ
            Section(header: Text("Управление данными")) {
                Button(action: {
                    showResetAlert = true
                }) {
                    HStack {
                        Text("Сбросить весь прогресс")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                // Логика предупреждения
                .alert("Вы уверены?", isPresented: $showResetAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Сбросить", role: .destructive) {
                        ProgressService.shared.resetProgress()
                    }
                } message: {
                    Text("Это действие нельзя отменить. Все выученные слова будут забыты.")
                }
            }
            
            Section(header: Text("О приложении")) {
                HStack {
                    Text("Версия")
                    Spacer()
                    Text("1.0.1 (Beta)")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func updateTheme(_ theme: Int) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let style: UIUserInterfaceStyle = theme == 1 ? .light : (theme == 2 ? .dark : .unspecified)
        
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.overrideUserInterfaceStyle = style
        }, completion: nil)
    }
}

#Preview {
    SettingsView()
}
