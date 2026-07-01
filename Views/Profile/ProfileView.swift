import SwiftUI
import SwiftData
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
    let progress: Double       // 0.0–1.0
    let progressLabel: String  // "28 / 500 слов"
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var avatarManager = AvatarManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showAllAchievements = false

    private static let achievementsPreviewCount = 6
    
    var body: some View {
        NavigationStack {
            List {
                headerSection
                
                // MARK: Активность
                let hasActivity = viewModel.activityData.contains { $0.xp > 0 }
                if hasActivity {
                    Section(L("profile.activity")) {
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(L("profile.achievements")).font(.headline)
                            Spacer()
                            let unlockedCount = viewModel.achievements.filter { $0.unlocked }.count
                            Text(L("profile.ach_progress_fmt", unlockedCount, viewModel.achievements.count))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(viewModel.achievements.prefix(Self.achievementsPreviewCount)) { item in
                                AchievementCardView(item: item)
                            }
                        }
                        if viewModel.achievements.count > Self.achievementsPreviewCount {
                            Button {
                                showAllAchievements = true
                            } label: {
                                Text(L("profile.show_all"))
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: Аккаунт
                Section(L("profile.account")) {
                    NavigationLink(value: ProfileRoute.personalData) {
                        Label { Text(L("profile.personal_data")) } icon: {
                            Image(systemName: "person.crop.circle").foregroundColor(.blue)
                        }
                    }
                    NavigationLink(value: ProfileRoute.vocabulary) {
                        Label {
                            HStack {
                                Text(L("profile.vocabulary"))
                                Spacer()
                                Text(L("profile.words_count_fmt", viewModel.totalLearnedWords))
                                    .foregroundColor(.secondary).font(.subheadline)
                            }
                        } icon: { Image(systemName: "book.closed.fill").foregroundColor(.indigo) }
                    }
                }

                // MARK: Настройки
                Section(L("profile.appearance")) {
                    Toggle(L("profile.system_theme"), isOn: $viewModel.useSystemTheme)
                        .onChange(of: viewModel.useSystemTheme) { _, newValue in
                            ThemeApplier.applyTheme(useSystemTheme: newValue, isDarkMode: viewModel.isDarkMode, animated: true)
                        }
                    if !viewModel.useSystemTheme {
                        Picker(L("profile.theme"), selection: $viewModel.isDarkMode) {
                            Text(L("profile.theme_light")).tag(false)
                            Text(L("profile.theme_dark")).tag(true)
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
                        DatePicker(L("profile.time"), selection: viewModel.notificationTimeBinding, displayedComponents: .hourAndMinute)
                    }
                }

                Section(L("profile.learning")) {
                    Picker(L("profile.daily_goal"), selection: $viewModel.dailyGoal) {
                        Text(L("profile.words_count_fmt", 5)).tag(5)
                        Text(L("profile.words_count_fmt", 10)).tag(10)
                        Text(L("profile.words_count_fmt", 20)).tag(20)
                    }
                    Button(role: .destructive) { viewModel.showResetAlert = true } label: {
                        Text(L("profile.reset"))
                    }
                }

                Section(L("profile.session")) {
                    Button(L("profile.sign_out")) { AuthManager.shared.signOut() }
                    Button(role: .destructive) { viewModel.showDeleteAccountAlert = true } label: {
                        Text(L("profile.delete"))
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Text(L("profile.version_fmt", viewModel.appVersion))
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("profile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .personalData:
                    PersonalDataView()
                case .vocabulary:
                    VocabularyView()
                }
            }
            .sheet(isPresented: $showAllAchievements) {
                AchievementsDetailView(achievements: viewModel.achievements)
            }
            .task {
                await viewModel.refreshGrammarLessonsTotal()
            }
            .onAppear {
                viewModel.loadActivity(context: modelContext)
                viewModel.loadStats(context: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                viewModel.loadActivity(context: modelContext)
                viewModel.loadStats(context: modelContext)
            }
            .alert(L("word.reset_title"), isPresented: $viewModel.showResetAlert) {
                Button(L("common.cancel"), role: .cancel) { }
                Button(L("word.reset_confirm"), role: .destructive) { viewModel.resetAllProgress() }
            }
            .alert(L("profile.delete_confirm_title"), isPresented: $viewModel.showDeleteAccountAlert) {
                Button(L("common.cancel"), role: .cancel) { }
                Button(L("common.delete"), role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
            } message: {
                Text(L("profile.delete_message"))
            }
            .alert(L("common.error"), isPresented: Binding(
                get: { viewModel.accountDeletionError != nil },
                set: { if !$0 { viewModel.accountDeletionError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.accountDeletionError ?? "")
            }
        }
    }
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 20) {
                // Аватарка + имя
                VStack(spacing: 10) {
                    AvatarView(
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
                                    value: "\(viewModel.dayStreak)", label: L("profile.days"))
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

struct AchievementCardView: View {
    let item: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(item.unlocked ? item.color.opacity(0.18) : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.body)
                        .foregroundColor(item.unlocked ? item.color : .secondary)
                }
                Spacer()
                if item.unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(item.color)
                        .font(.title3)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline).bold()
                    .foregroundColor(item.unlocked ? .primary : .secondary)
                Text(item.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if !item.unlocked {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: item.progress)
                        .tint(item.color)
                    Text(item.progressLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            item.unlocked
                ? item.color.opacity(0.07)
                : Color(UIColor.secondarySystemGroupedBackground)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.unlocked ? item.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
