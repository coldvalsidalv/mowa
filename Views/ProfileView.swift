import SwiftUI
import PhotosUI
import Charts

// --- 1. МАРШРУТЫ (ENUM) ---
enum ProfileRoute: Hashable {
    case personalData
    case vocabulary
}

// --- МОДЕЛИ ---
struct ActivityData: Identifiable {
    let id = UUID()
    let day: String
    let xp: Int
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let unlocked: Bool
}

// --- ГЛАВНЫЙ ЭКРАН ПРОФИЛЯ ---
struct ProfileView: View {
    // --- ДАННЫЕ ---
    @AppStorage("userName") private var userName: String = "Uladzislau Kisialiou"
    @AppStorage("userEmail") private var userEmail: String = "uladzislaukisialiou@gmail.com"
    @AppStorage("totalLearnedWords") private var totalLearnedWords: Int = 142
    @AppStorage("dayStreak") private var dayStreak: Int = 5
    @AppStorage("dailyGoal") private var dailyGoal: Int = 10
    @AppStorage("userAvatarData") private var avatarData: Data = Data()
    @AppStorage("userXP") private var userXP: Int = 1250
    
    // --- НАСТРОЙКИ ---
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("useSystemTheme") private var useSystemTheme: Bool = true
    @AppStorage("appLanguage") private var appLanguage: String = "Ru"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("notificationTime") private var notificationTimeInterval: Double = 32400
    
    // --- UI STATE ---
    @State private var showDeleteAlert = false
    @State private var showResetAlert = false
    @State private var showAchievementsDetail = false
    @State private var notifTimeDate: Date = Date()
    @State private var learnedWordsCount: Int = 0
    
    // Демо-данные
    let activityData: [ActivityData] = [
        .init(day: "Пн", xp: 40), .init(day: "Вт", xp: 65), .init(day: "Ср", xp: 30),
        .init(day: "Чт", xp: 90), .init(day: "Пт", xp: 55), .init(day: "Сб", xp: 120),
        .init(day: "Вс", xp: 80)
    ]
    
    let achievements: [Achievement] = [
        .init(title: "Первые шаги", description: "Завершите первый урок без ошибок", icon: "shoe.fill", color: .blue, unlocked: true),
        .init(title: "Огонь", description: "Поддерживайте серию 7 дней подряд", icon: "flame.fill", color: .orange, unlocked: true),
        .init(title: "Полиглот", description: "Выучите 500 новых слов", icon: "globe.europe.africa.fill", color: .green, unlocked: false),
        .init(title: "Ночная сова", description: "Пройдите урок после 23:00", icon: "moon.stars.fill", color: .purple, unlocked: false)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                // 1. ХЕДЕР (Исправленный: без отрицательных отступов)
                headerSection
                
                // 2. МЕНЮ АККАУНТА
                Section("Аккаунт") {
                    NavigationLink(value: ProfileRoute.personalData) {
                        Label { Text("Персональные данные") } icon: { Image(systemName: "person.crop.circle").foregroundColor(.blue) }
                    }
                    
                    NavigationLink(value: ProfileRoute.vocabulary) {
                        Label {
                            HStack {
                                Text("Мой словарь")
                                Spacer()
                                Text("\(totalLearnedWords) слов").foregroundColor(.secondary).font(.subheadline)
                            }
                        } icon: { Image(systemName: "book.closed.fill").foregroundColor(.indigo) }
                    }
                    
                    ShareLink(item: URL(string: "https://mova.app")!) {
                        Label { Text("Пригласить друзей") } icon: { Image(systemName: "square.and.arrow.up").foregroundColor(.green) }
                    }
                }
                
                // 3. СТАТИСТИКА
                Section {
                    HStack(alignment: .center) {
                        CompactStatItem(value: "\(totalLearnedWords)", title: "Слов")
                        Divider()
                        CompactStatItem(value: "\(dayStreak)", title: "Дней", icon: "flame.fill", color: .orange)
                        Divider()
                        CompactStatItem(value: "\(userXP)", title: "XP")
                        Divider()
                        CompactStatItem(value: "III", title: "Лига", icon: "shield.fill", color: .brown)
                    }
                    .padding(.vertical, 8)
                }
                
                // 4. АКТИВНОСТЬ
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Активность").font(.headline)
                        Chart {
                            ForEach(activityData) { item in
                                BarMark(
                                    x: .value("Day", item.day),
                                    y: .value("XP", item.xp)
                                )
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top))
                                .cornerRadius(6)
                            }
                        }
                        .frame(height: 160)
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2).foregroundStyle(.secondary) } }
                    }
                    .padding(.vertical, 12)
                }
                
                // 5. ДОСТИЖЕНИЯ
                Section {
                    Button(action: { showAchievementsDetail = true }) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Достижения").font(.headline).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(achievements) { item in
                                        AchievementItemView(item: item)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .sheet(isPresented: $showAchievementsDetail) {
                    AchievementsDetailView(achievements: achievements)
                }
                
                // 6. ВНЕШНИЙ ВИД
                Section("Внешний вид") {
                    Toggle("Системная тема", isOn: $useSystemTheme)
                        .onChange(of: useSystemTheme) { _, _ in applyTheme(animated: true) }
                    
                    if !useSystemTheme {
                        Picker("Тема", selection: $isDarkMode) {
                            Text("Светлая ☀️").tag(false)
                            Text("Темная 🌙").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 6)
                        .onChange(of: isDarkMode) { _, _ in applyTheme(animated: true) }
                    }
                }
                
                // 7. НАСТРОЙКИ
                Section("Настройки") {
                    Picker("Язык", selection: $appLanguage) {
                        Text("Русский").tag("Ru")
                        Text("Polski").tag("Pl")
                        Text("English").tag("En")
                    }
                    Toggle("Уведомления", isOn: $notificationsEnabled)
                    if notificationsEnabled {
                        DatePicker("Время", selection: $notifTimeDate, displayedComponents: .hourAndMinute)
                            .onChange(of: notifTimeDate) { _, newValue in notificationTimeInterval = newValue.timeIntervalSince1970 }
                    }
                }
                
                // 8. ЦЕЛИ
                Section("Цели и данные") {
                    Picker("Дневная цель", selection: $dailyGoal) {
                        Text("5 слов").tag(5)
                        Text("10 слов").tag(10)
                        Text("20 слов").tag(20)
                    }
                    Button(role: .destructive) { showResetAlert = true } label: { Text("Сбросить прогресс") }
                }
                
                // 9. УДАЛИТЬ АККАУНТ
                Section {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Text("Удалить аккаунт")
                            .font(.body)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // 10. ФУТЕР
                Section {
                    HStack {
                        Spacer()
                        Text("Версия 1.0.5 • Mova App")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            // НАВИГАЦИЯ
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .personalData:
                    PersonalDataView()
                case .vocabulary:
                    VocabularyView(wordsCount: totalLearnedWords)
                }
            }
            .onAppear {
                updateStats()
                notifTimeDate = Date(timeIntervalSince1970: notificationTimeInterval)
                applyTheme(animated: false)
            }
            .alert("Удалить аккаунт?", isPresented: $showDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) { deleteAccount() }
            } message: { Text("Это действие нельзя отменить.") }
            .alert("Сбросить прогресс?", isPresented: $showResetAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сбросить", role: .destructive) { resetAllProgress() }
            }
        }
    }
    
    // MARK: - HEADER SECTION (Apple Guidelines)
    private var headerSection: some View {
        Section {
            VStack(spacing: 8) {
                if let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle().fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay {
                             Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45)
                                .foregroundColor(.gray)
                                .offset(y: 4)
                        }
                }
                
                VStack(spacing: 2) {
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.semibold) // Apple использует semibold, не bold
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(userEmail)
                        .font(.footnote) // Footnote аккуратнее для подписи
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            // ВАЖНО: Мы убрали отрицательные отступы. Теперь аватарка не будет обрезаться.
            // Мы просто убираем отступ сверху у контейнера.
            .padding(.top, 0)
            .padding(.bottom, 12)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets()) // Полный сброс отступов ячейки
    }
    
    // --- ЛОГИКА ТЕМЫ ---
    private func applyTheme(animated: Bool) {
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
    
    func updateStats() { learnedWordsCount = ProgressService.shared.getLearnedIDs().count }
    func resetAllProgress() { ProgressService.shared.resetProgress(); updateStats() }
    func deleteAccount() { resetAllProgress(); userName = ""; userEmail = ""; avatarData = Data() }
}

// MARK: - ЭКРАН РЕДАКТИРОВАНИЯ
struct PersonalDataView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage("userAvatarData") private var avatarData: Data = Data()
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            if let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable().scaledToFill()
                                    .frame(width: 100, height: 100).clipShape(Circle())
                            } else {
                                Circle().fill(Color.gray.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                    .overlay(Text("Изменить").foregroundColor(.blue))
                            }
                            Image(systemName: "camera.fill")
                                .font(.headline).foregroundColor(.white)
                                .padding(8).background(Color.blue).clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .offset(x: 35, y: 35)
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                withAnimation { avatarData = data }
                            }
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            Section("Основное") {
                TextField("Ваше имя", text: $userName)
                TextField("Email", text: $userEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            
            Section("Безопасность") {
                NavigationLink("Сменить пароль") { Text("Экран смены пароля") }
            }
            
            Section("Синхронизация") {
                Toggle(isOn: .constant(true)) { Label("iCloud Sync", systemImage: "icloud.fill") }
                Toggle(isOn: .constant(false)) { Label("Google Sync", systemImage: "g.circle.fill") }
            }
        }
        .navigationTitle("Персональные данные")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ЭКРАН СЛОВАРЯ
struct VocabularyView: View {
    let wordsCount: Int
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Всего слов").font(.caption).foregroundColor(.secondary)
                        Text("\(wordsCount)").font(.largeTitle).bold().foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 40)).foregroundColor(.blue.opacity(0.2))
                }
            }
            
            Section("Недавно изученные") {
                ForEach(1...5, id: \.self) { i in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Word \(i)").font(.headline)
                            Text("Перевод \(i)").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "speaker.wave.2.fill").foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Мой словарь")
    }
}

// MARK: - ДЕТАЛИ АЧИВОК
struct AchievementsDetailView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(achievements) { item in
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.title)
                        .foregroundColor(item.unlocked ? item.color : .gray)
                        .frame(width: 50, height: 50)
                        .background(item.unlocked ? item.color.opacity(0.1) : Color.gray.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline).foregroundColor(item.unlocked ? .primary : .secondary)
                        Text(item.description).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if item.unlocked {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Все достижения")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - ХЕЛПЕРЫ
struct CompactStatItem: View {
    let value: String; let title: String; var icon: String? = nil; var color: Color = .primary
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if let icon = icon { Image(systemName: icon).font(.caption2).foregroundColor(color) }
                Text(value).font(.headline).fontWeight(.semibold).foregroundColor(color == .primary ? .primary : color)
            }
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AchievementItemView: View {
    let item: Achievement
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(item.unlocked ? item.color.opacity(0.15) : Color.gray.opacity(0.1)).frame(width: 60, height: 60)
                Image(systemName: item.icon).font(.title3).foregroundColor(item.unlocked ? item.color : .gray)
            }
            Text(item.title).font(.caption2).fontWeight(.medium).foregroundColor(item.unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 80)
    }
}
