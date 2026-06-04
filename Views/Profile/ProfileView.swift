import SwiftUI
import PhotosUI
import Charts

enum ProfileRoute: Hashable {
    case personalData
    case vocabulary
}

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

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var avatarManager = AvatarManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                headerSection
                
                // MARK: Прогресс слов
                Section("Прогресс слов") {
                    let total = viewModel.wordsLearning + viewModel.wordsKnown + viewModel.wordsMastered
                    if total == 0 {
                        Text("Начни учить слова — здесь появится твой прогресс")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        HStack(spacing: 0) {
                            ProfileStatItem(icon: "circle.fill", color: .orange, value: "\(viewModel.wordsLearning)", label: "Учу")
                            Divider().frame(height: 36)
                            ProfileStatItem(icon: "circle.fill", color: .blue, value: "\(viewModel.wordsKnown)", label: "Знаю")
                            Divider().frame(height: 36)
                            ProfileStatItem(icon: "circle.fill", color: .green, value: "\(viewModel.wordsMastered)", label: "Выучено")
                        }
                        .padding(.vertical, 10)

                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                if viewModel.wordsLearning > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.orange)
                                        .frame(width: geo.size.width * CGFloat(viewModel.wordsLearning) / CGFloat(total))
                                }
                                if viewModel.wordsKnown > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.blue)
                                        .frame(width: geo.size.width * CGFloat(viewModel.wordsKnown) / CGFloat(total))
                                }
                                if viewModel.wordsMastered > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.green)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 6)
                        .padding(.bottom, 8)
                    }
                }

                // MARK: Активность
                let hasActivity = viewModel.activityData.contains { $0.xp > 0 }
                if hasActivity {
                    Section("Активность") {
                        Chart(viewModel.activityData) { item in
                            BarMark(x: .value("Day", item.day), y: .value("XP", item.xp))
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top))
                                .cornerRadius(6)
                        }
                        .frame(height: 130)
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2).foregroundStyle(.secondary) } }
                        .padding(.vertical, 8)
                    }
                }

                // MARK: Достижения
                Section {
                    Button(action: { viewModel.showAchievementsDetail = true }) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Достижения").font(.headline).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(viewModel.achievements) { item in
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

                // MARK: Аккаунт
                Section("Аккаунт") {
                    NavigationLink(value: ProfileRoute.personalData) {
                        Label { Text("Персональные данные") } icon: {
                            Image(systemName: "person.crop.circle").foregroundColor(.blue)
                        }
                    }
                    NavigationLink(value: ProfileRoute.vocabulary) {
                        Label {
                            HStack {
                                Text("Мой словарь")
                                Spacer()
                                Text("\(viewModel.totalLearnedWords) слов")
                                    .foregroundColor(.secondary).font(.subheadline)
                            }
                        } icon: { Image(systemName: "book.closed.fill").foregroundColor(.indigo) }
                    }
                }

                // MARK: Настройки
                Section("Внешний вид") {
                    Toggle("Системная тема", isOn: $viewModel.useSystemTheme)
                        .onChange(of: viewModel.useSystemTheme) { _, newValue in
                            ThemeApplier.applyTheme(useSystemTheme: newValue, isDarkMode: viewModel.isDarkMode, animated: true)
                        }
                    if !viewModel.useSystemTheme {
                        Picker("Тема", selection: $viewModel.isDarkMode) {
                            Text("Светлая ☀️").tag(false)
                            Text("Темная 🌙").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 6)
                        .onChange(of: viewModel.isDarkMode) { _, newValue in
                            ThemeApplier.applyTheme(useSystemTheme: viewModel.useSystemTheme, isDarkMode: newValue, animated: true)
                        }
                    }
                }

                Section(L("profile.settings")) {
                    Picker(L("profile.language"), selection: $viewModel.appLanguage) {
                        Text("Русский").tag("ru")
                        Text("Українська").tag("uk")
                        Text("English").tag("en")
                    }
                    .onChange(of: viewModel.appLanguage) { _, newLang in
                        LanguageManager.shared.setLanguage(newLang)
                    }
                    Toggle(L("profile.notifications"), isOn: $viewModel.notificationsEnabled)
                        .onChange(of: viewModel.notificationsEnabled) { _, isEnabled in
                            viewModel.toggleNotifications(isEnabled)
                        }
                    if viewModel.notificationsEnabled {
                        DatePicker("Время", selection: viewModel.notificationTimeBinding, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Обучение") {
                    Picker("Дневная цель", selection: $viewModel.dailyGoal) {
                        Text("5 слов").tag(5)
                        Text("10 слов").tag(10)
                        Text("20 слов").tag(20)
                    }
                    Button(role: .destructive) { viewModel.showResetAlert = true } label: {
                        Text("Сбросить прогресс")
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Text("Версия \(viewModel.appVersion) • Verbum")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .personalData:
                    PersonalDataView()
                case .vocabulary:
                    VocabularyView()
                }
            }
            .onAppear {
                viewModel.refreshLearnedCount(context: modelContext)
                viewModel.loadActivity(context: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                viewModel.refreshLearnedCount(context: modelContext)
                viewModel.loadActivity(context: modelContext)
            }
            .sheet(isPresented: $viewModel.showAchievementsDetail) {
                AchievementsDetailView(achievements: viewModel.achievements)
            }
            .alert("Сбросить прогресс?", isPresented: $viewModel.showResetAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сбросить", role: .destructive) { viewModel.resetAllProgress() }
            }
        }
    }
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 20) {
                // Аватарка + имя
                VStack(spacing: 10) {
                    AvatarView(
                        urlString: nil,
                        localImage: avatarManager.avatar,
                        name: viewModel.displayName,
                        color: .blue,
                        size: 88
                    )
                    VStack(spacing: 2) {
                        Text(viewModel.displayName)
                            .font(.title3).fontWeight(.semibold)
                        if !viewModel.userEmail.isEmpty {
                            Text(viewModel.userEmail)
                                .font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }

                // Статистика
                HStack(spacing: 0) {
                    ProfileStatItem(icon: "flame.fill", color: .orange,
                                    value: "\(viewModel.dayStreak)", label: "Дней")
                    Divider().frame(height: 32)
                    ProfileStatItem(icon: "star.fill", color: .yellow,
                                    value: "\(viewModel.userXP)", label: "XP")
                    Divider().frame(height: 32)
                    ProfileStatItem(
                        icon: viewModel.currentLeague.icon,
                        color: viewModel.currentLeague.color,
                        value: "",
                        label: viewModel.currentLeague.shortTitle
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

struct ProfileStatItem: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Text(label).font(.caption2).foregroundColor(.secondary)
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
