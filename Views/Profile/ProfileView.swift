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
    
    var body: some View {
        NavigationStack {
            List {
                headerSection
                
                Section("Аккаунт") {
                    NavigationLink(value: ProfileRoute.personalData) {
                        Label { Text("Персональные данные") } icon: { Image(systemName: "person.crop.circle").foregroundColor(.blue) }
                    }
                    NavigationLink(value: ProfileRoute.vocabulary) {
                        Label {
                            HStack {
                                Text("Мой словарь")
                                Spacer()
                                Text("\(viewModel.totalLearnedWords) слов").foregroundColor(.secondary).font(.subheadline)
                            }
                        } icon: { Image(systemName: "book.closed.fill").foregroundColor(.indigo) }
                    }
                    ShareLink(item: URL(string: "https://mova.app")!) {
                        Label { Text("Пригласить друзей") } icon: { Image(systemName: "square.and.arrow.up").foregroundColor(.green) }
                    }
                }
                
                Section {
                    HStack(alignment: .center) {
                        CompactStatItem(value: "\(viewModel.totalLearnedWords)", title: "Слов")
                        Divider()
                        CompactStatItem(value: "\(viewModel.dayStreak)", title: "Дней", icon: "flame.fill", color: .orange)
                        Divider()
                        CompactStatItem(value: "\(viewModel.userXP)", title: "XP")
                        Divider()
                        CompactStatItem(value: "III", title: "Лига", icon: "shield.fill", color: .brown)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Активность").font(.headline)
                        Chart(viewModel.activityData) { item in
                            BarMark(x: .value("Day", item.day), y: .value("XP", item.xp))
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top))
                                .cornerRadius(6)
                        }
                        .frame(height: 160)
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2).foregroundStyle(.secondary) } }
                    }
                    .padding(.vertical, 12)
                }
                
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
                
                Section("Настройки") {
                    Picker("Язык", selection: $viewModel.appLanguage) {
                        Text("Русский").tag("Ru")
                        Text("Polski").tag("Pl")
                        Text("English").tag("En")
                    }
                    Toggle("Уведомления", isOn: $viewModel.notificationsEnabled)
                        .onChange(of: viewModel.notificationsEnabled) { _, isEnabled in
                            viewModel.toggleNotifications(isEnabled)
                        }
                    
                    if viewModel.notificationsEnabled {
                        DatePicker("Время", selection: viewModel.notificationTimeBinding, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("Цели и данные") {
                    Picker("Дневная цель", selection: $viewModel.dailyGoal) {
                        Text("5 слов").tag(5)
                        Text("10 слов").tag(10)
                        Text("20 слов").tag(20)
                    }
                    Button(role: .destructive) { viewModel.showResetAlert = true } label: { Text("Сбросить прогресс") }
                }
                
                Section {
                    Button(action: { viewModel.showDeleteAlert = true }) {
                        Text("Удалить аккаунт").font(.body).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        Text("Версия 1.0.5 • Mova App").font(.caption2).foregroundColor(.secondary)
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
                    VocabularyView(wordsCount: viewModel.totalLearnedWords)
                }
            }
            .sheet(isPresented: $viewModel.showAchievementsDetail) {
                AchievementsDetailView(achievements: viewModel.achievements)
            }
            .alert("Удалить аккаунт?", isPresented: $viewModel.showDeleteAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) { viewModel.deleteAccount() }
            } message: { Text("Это действие нельзя отменить.") }
            .alert("Сбросить прогресс?", isPresented: $viewModel.showResetAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сбросить", role: .destructive) { viewModel.resetAllProgress() }
            }
        }
    }
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 8) {
                AvatarView(
                    urlString: nil,
                    localImage: avatarManager.avatar,
                    name: viewModel.userName,
                    color: .blue,
                    size: 100
                )
                
                VStack(spacing: 2) {
                    Text(viewModel.userName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(viewModel.userEmail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 0)
            .padding(.bottom, 12)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

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
