import SwiftUI

struct ProfileView: View {
    // --- ХРАНИЛИЩЕ ДАННЫХ ---
    @AppStorage("userName") private var userName: String = "Uladzislau"
    @AppStorage("dayStreak") private var dayStreak: Int = 1
    @AppStorage("dailyGoal") private var dailyGoal: Int = 10
    
    // Настройки
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("useSystemTheme") private var useSystemTheme: Bool = true
    @AppStorage("appLanguage") private var appLanguage: String = "Ru"
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("notificationTime") private var notificationTimeInterval: Double = 32400
    
    @State private var showResetAlert = false
    @State private var learnedWordsCount: Int = 0
    @State private var notifTimeDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            List {
                // СЕКЦИЯ 1: ПРОФИЛЬ
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 70, height: 70)
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cześć,")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Twoje imię", text: $userName)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // СЕКЦИЯ 2: СТАТИСТИКА
                Section("Statystyki") {
                    StatsRow(icon: "flame.fill", color: .orange, title: "Dni z rzędu", value: "\(dayStreak)")
                    StatsRow(icon: "book.closed.fill", color: .green, title: "Słowa wyuczone", value: "\(learnedWordsCount)")
                }
                
                // СЕКЦИЯ 3: ВНЕШНИЙ ВИД (ТВОЯ ЛОГИКА)
                Section("Wygląd") {
                    Toggle("Motyw systemowy", isOn: $useSystemTheme)
                        .onChange(of: useSystemTheme) { _, _ in
                            applyTheme()
                        }
                    
                    if !useSystemTheme {
                        Picker("Motyw", selection: $isDarkMode) {
                            Text("Jasny ☀️").tag(false)
                            Text("Ciemny 🌙").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: isDarkMode) { _, _ in
                            applyTheme()
                        }
                    }
                }
                
                // СЕКЦИЯ 4: НАСТРОЙКИ
                Section("Ustawienia aplikacji") {
                    Picker("Język", selection: $appLanguage) {
                        Text("Русский").tag("Ru")
                        Text("Polski").tag("Pl")
                        Text("English").tag("En")
                    }
                    
                    Toggle("Powiadomienia", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        DatePicker("Czas przypomnienia", selection: $notifTimeDate, displayedComponents: .hourAndMinute)
                            .onChange(of: notifTimeDate) { _, newValue in
                                notificationTimeInterval = newValue.timeIntervalSince1970
                            }
                    }
                }
                
                // СЕКЦИЯ 5: ЦЕЛИ
                Section("Cele") {
                    Picker("Dzienny cel", selection: $dailyGoal) {
                        Text("5 słów").tag(5)
                        Text("10 słów").tag(10)
                        Text("20 słów").tag(20)
                        Text("50 słów").tag(50)
                    }
                    
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Zresetuj postęp")
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Wersja")
                        Spacer()
                        Text("1.0.5")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Stworzono z ❤️ do języka polskiego")
                        .padding(.top)
                }
            }
            .navigationTitle("Profil")
            .onAppear {
                updateStats()
                notifTimeDate = Date(timeIntervalSince1970: notificationTimeInterval)
                // Применяем тему при загрузке экрана, чтобы не слетала
                applyTheme()
            }
            .alert("Zresetować postęp?", isPresented: $showResetAlert) {
                Button("Anuluj", role: .cancel) { }
                Button("Zresetuj", role: .destructive) {
                    resetAllProgress()
                }
            } message: {
                Text("Usuniemy wszystkie twoje osiągnięcia. Jesteś pewien?")
            }
        }
    }
    
    // MARK: - ГЛОБАЛЬНАЯ СМЕНА ТЕМЫ (UIWindow)
    
    private func applyTheme() {
        // Получаем текущее активное окно (современный аналог keyWindow)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        // Определяем стиль
        let style: UIUserInterfaceStyle
        if useSystemTheme {
            style = .unspecified
        } else {
            style = isDarkMode ? .dark : .light
        }
        
        // АНИМАЦИЯ: Плавный переход (Cross Dissolve) для всего окна
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            // Вот твоя строка, адаптированная под SceneDelegate
            window.overrideUserInterfaceStyle = style
        }, completion: nil)
    }
    
    // MARK: - Helpers
    func updateStats() {
        learnedWordsCount = ProgressService.shared.getLearnedIDs().count
    }
    
    func resetAllProgress() {
        ProgressService.shared.resetProgress()
        dayStreak = 0
        updateStats()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Subviews
struct StatsRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .bold()
        }
    }
}
