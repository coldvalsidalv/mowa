import SwiftUI
import Combine

// MARK: - HELPERS
class HapticManager {
    static let instance = HapticManager()
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - MODELS

enum LeagueType: Int, CaseIterable, Identifiable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case diamond = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .bronze: return "Liga Brązowa"
        case .silver: return "Liga Srebrna"
        case .gold: return "Liga Złota"
        case .diamond: return "Liga Diamentowa"
        }
    }
    
    var iconName: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.fill"
        case .gold: return "crown.fill"
        case .diamond: return "diamond.fill"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.6, green: 0.4, blue: 0.2)]
        case .silver:
            return [Color(red: 0.8, green: 0.8, blue: 0.85), Color(red: 0.5, green: 0.55, blue: 0.6)]
        case .gold:
            return [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.1)]
        case .diamond:
            return [Color.cyan, Color.blue]
        }
    }
    
    var nextLeague: LeagueType? {
        return LeagueType(rawValue: self.rawValue + 1)
    }
    
    var prevLeague: LeagueType? {
        return LeagueType(rawValue: self.rawValue - 1)
    }
}

struct LeaderboardUser: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let xp: Int
    let avatarColor: Color
    let isCurrentUser: Bool
    
    var streak: Int = Int.random(in: 1...50)
    var totalWords: Int = Int.random(in: 500...3000)
    var leagueWords: Int = Int.random(in: 50...200)
}

// MARK: - MAIN VIEW

struct LeaderboardView: View {
    @State private var podiumsVisible = false
    @State private var timeRemaining: String = "--h --m"
    @State private var selectedUser: LeaderboardUser? = nil
    @State private var showLeagueMap = false
    @State private var isCurrentUserVisible = false
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    let currentLeague: LeagueType = .silver
    
    // ГЕНЕРАЦИЯ ДАННЫХ
    let users: [LeaderboardUser] = {
        var list = [
            LeaderboardUser(rank: 1, name: "Anna K.", xp: 2450, avatarColor: .purple, isCurrentUser: false),
            LeaderboardUser(rank: 2, name: "Marek W.", xp: 2100, avatarColor: .blue, isCurrentUser: false),
            LeaderboardUser(rank: 3, name: "Kasia L.", xp: 1950, avatarColor: .pink, isCurrentUser: false),
            // Текущий юзер в зоне вылета (22 место)
            LeaderboardUser(rank: 22, name: "Uladzislau", xp: 850, avatarColor: .green, isCurrentUser: true)
        ]
        
        for i in 4...30 {
            if i == 22 { continue }
            let user = LeaderboardUser(
                rank: i,
                name: "User \(i)",
                xp: 2000 - (i * 40),
                avatarColor: [.orange, .red, .gray, .cyan, .mint, .indigo, .brown].randomElement()!,
                isCurrentUser: false
            )
            list.append(user)
        }
        return list.sorted(by: { $0.rank < $1.rank })
    }()
    
    var currentUser: LeaderboardUser? {
        users.first(where: { $0.isCurrentUser })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // 1. HEADER
                        Button {
                            HapticManager.instance.impact(style: .medium)
                            showLeagueMap = true
                        } label: {
                            LeagueCardHeader(currentLeague: currentLeague, timeRemaining: timeRemaining)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .padding(.top, 0)
                        
                        // 2. PODIUM
                        HStack(alignment: .bottom, spacing: 16) {
                            if users.count > 1 {
                                PodiumView(user: users[1], height: 140, color: .gray, isVisible: podiumsVisible)
                                    .onTapGesture { openUserProfile(users[1]) }
                            }
                            if users.count > 0 {
                                PodiumView(user: users[0], height: 170, color: .yellow, isVisible: podiumsVisible)
                                    .scaleEffect(1.1)
                                    .zIndex(1)
                                    .onTapGesture { openUserProfile(users[0]) }
                            }
                            if users.count > 2 {
                                PodiumView(user: users[2], height: 120, color: .brown, isVisible: podiumsVisible)
                                    .onTapGesture { openUserProfile(users[2]) }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 40)
                        
                        // 3. LIST
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Top 30")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(users.dropFirst(3)) { user in
                                    LeaderboardRow(user: user)
                                        .onTapGesture { openUserProfile(user) }
                                        .onAppear {
                                            if user.isCurrentUser { withAnimation { isCurrentUserVisible = true } }
                                        }
                                        .onDisappear {
                                            if user.isCurrentUser { withAnimation { isCurrentUserVisible = false } }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            // Небольшой отступ снизу, остальное обработает safeAreaInset
                            .padding(.bottom, 20)
                        }
                    }
                }
                // ИСПРАВЛЕНИЕ БАГА: Принудительный отскок всегда
                .scrollBounceBehavior(.always, axes: .vertical)
            }
            .navigationTitle("Ranking")
            // 4. STICKY ROW
            .safeAreaInset(edge: .bottom) {
                if let me = currentUser, !isCurrentUserVisible {
                    StickyUserRow(user: me, currentLeague: currentLeague)
                        .onTapGesture { openUserProfile(me) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $selectedUser) { user in
                RivalProfileView(user: user)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showLeagueMap) {
                LeagueMapView(currentLeague: currentLeague)
                    .presentationDetents([.fraction(0.7)])
            }
            .onAppear {
                updateTimeRemaining()
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                    podiumsVisible = true
                }
            }
            .onReceive(timer) { _ in updateTimeRemaining() }
        }
    }
    
    private func openUserProfile(_ user: LeaderboardUser) {
        HapticManager.instance.impact(style: .light)
        selectedUser = user
    }
    
    private func updateTimeRemaining() {
        let calendar = Calendar.current
        let now = Date()
        var nextSundayComponents = DateComponents()
        nextSundayComponents.weekday = 1
        nextSundayComponents.hour = 20
        nextSundayComponents.minute = 0
        nextSundayComponents.second = 0
        
        guard let nextSunday = calendar.nextDate(after: now, matching: nextSundayComponents, matchingPolicy: .nextTime) else { return }
        let diff = calendar.dateComponents([.day, .hour, .minute], from: now, to: nextSunday)
        
        if let day = diff.day, let hour = diff.hour, let minute = diff.minute {
            timeRemaining = day > 0 ? "\(day)d \(hour)h" : "\(hour)h \(minute)m"
        }
    }
}

// MARK: - STICKY USER ROW
struct StickyUserRow: View {
    let user: LeaderboardUser
    let currentLeague: LeagueType
    
    enum Status {
        case promoting
        case safe
        case demoting
    }
    
    var status: Status {
        if user.rank <= 10 { return .promoting }
        if user.rank <= 20 { return .safe }
        return .demoting
    }
    
    var statusColor: Color {
        switch status {
        case .promoting: return .green
        case .safe: return .orange
        case .demoting: return .red
        }
    }
    
    var statusIcon: String {
        switch status {
        case .promoting: return "arrow.up.circle.fill"
        case .safe: return "exclamationmark.triangle.fill"
        case .demoting: return "arrow.down.circle.fill"
        }
    }
    
    var statusTitle: String {
        switch status {
        case .promoting: return "Strefa awansu!"
        case .safe: return "Brak awansu"
        case .demoting: return "Strefa spadku!"
        }
    }
    
    var statusMessage: String {
        switch status {
        case .promoting:
            return "Awansujesz do ligi \(currentLeague.nextLeague?.title ?? "wyżej")"
        case .safe:
            return "Musisz być w Top 10, by awansować"
        case .demoting:
            return "Spadniesz do ligi \(currentLeague.prevLeague?.title ?? "niżej")"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(statusColor)
                .frame(height: 3)
            
            HStack(spacing: 16) {
                Text("\(user.rank)")
                    .font(.headline)
                    .foregroundColor(statusColor)
                    .frame(width: 30)
                
                Circle()
                    .fill(user.avatarColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(user.name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(user.avatarColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(statusTitle)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(statusColor)
                        
                        Image(systemName: statusIcon)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                    
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(user.xp)")
                        .font(.headline).bold()
                    Text("XP").font(.caption2).foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
        }
    }
}

// MARK: - LEADERBOARD ROW
struct LeaderboardRow: View {
    let user: LeaderboardUser
    
    var statusColor: Color {
        if user.rank <= 10 { return .green }
        if user.rank > 20 { return .red }
        return .clear
    }
    
    var body: some View {
        HStack(spacing: 16) {
            if statusColor != .clear {
                Capsule()
                    .fill(statusColor)
                    .frame(width: 4, height: 24)
            } else {
                Color.clear.frame(width: 4, height: 24)
            }
            
            Text("\(user.rank)")
                .font(.headline)
                .foregroundColor(statusColor == .clear ? .gray : statusColor)
                .frame(width: 25)
            
            Circle()
                .fill(user.avatarColor.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(user.name.prefix(1)))
                        .font(.title3)
                        .bold()
                        .foregroundColor(user.avatarColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(user.isCurrentUser ? .blue : .primary)
                
                if user.rank <= 10 {
                    Text("Strefa awansu")
                        .font(.caption2).foregroundColor(.green).bold()
                } else if user.rank > 20 {
                    Text("Strefa spadku")
                        .font(.caption2).foregroundColor(.red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(user.xp)")
                    .font(.headline).bold()
                Text("XP").font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            user.isCurrentUser ? Color.blue.opacity(0.08) :
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
    }
}

// MARK: - SUBVIEWS (PROFILE, MAP, ETC)
// MARK: - COMPONENT: RIVAL PROFILE (UPDATED)
struct RivalProfileView: View {
    let user: LeaderboardUser
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Ручка шторки
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            // Аватар и Имя
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(user.avatarColor.opacity(0.2))
                        .frame(width: 90, height: 90)
                    
                    Text(String(user.name.prefix(1)))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(user.avatarColor)
                    
                    // Небольшой бейдж с рангом прямо на аватаре
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.primary)
                                .colorInvert() // Контрастный цвет
                                .frame(width: 28, height: 28)
                                .shadow(radius: 2)
                                .overlay(
                                    Text("\(user.rank)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.primary)
                                )
                                .offset(x: 0, y: 0)
                        }
                    }
                    .frame(width: 90, height: 90)
                }
                
                Text(user.name)
                    .font(.title2)
                    .bold()
                
                // Статус текстом
                if user.rank <= 10 {
                    Text("🔥 Walczy o awans")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                } else if user.rank > 20 {
                    Text("⚠️ Zagrożony spadkiem")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                } else {
                    Text("🛡️ Bezpieczna pozycja")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                }
            }
            
            Divider()
                .padding(.horizontal)
            
            // Статистика (Обновленные названия)
            HStack(alignment: .top, spacing: 0) {
                // 1. Страйк
                StatColumn(
                    value: "\(user.streak)",
                    label: "Dni z rzędu",
                    icon: "flame.fill",
                    color: .orange
                )
                
                // Разделитель
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 40)
                    .padding(.top, 10)
                
                // 2. Общий словарь
                StatColumn(
                    value: "\(user.totalWords)",
                    label: "Znane słowa", // Было "Wszystkie słowa"
                    icon: "book.closed.fill",
                    color: .blue
                )
                
                // Разделитель
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 40)
                    .padding(.top, 10)
                
                // 3. Прогресс в текущей лиге
                StatColumn(
                    value: "+\(user.leagueWords)",
                    label: "Nowe (Tydzień)", // Было "W tej lidze"
                    icon: "chart.line.uptrend.xyaxis", // Иконка графика роста
                    color: .green
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                HapticManager.instance.impact(style: .medium)
                dismiss()
            } label: {
                Text("Zamknij")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top)
    }
}
struct StatColumn: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(color).frame(height: 24)
            Text(value).font(.title3).bold()
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LeagueMapView: View {
    let currentLeague: LeagueType
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(LeagueType.allCases) { league in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(league.gradientColors.first!.opacity(0.2)).frame(width: 50, height: 50)
                            Image(systemName: league.iconName).foregroundColor(league.gradientColors.first!).font(.title2)
                        }
                        VStack(alignment: .leading) {
                            Text(league.title).font(.headline).foregroundColor(league.rawValue <= currentLeague.rawValue ? .primary : .gray)
                            if league.rawValue == currentLeague.rawValue { Text("Bieżąca liga").font(.caption).foregroundColor(.blue).bold() }
                            else if league.rawValue < currentLeague.rawValue { Text("Ukończona").font(.caption).foregroundColor(.green) }
                            else { Text("Zablokowana").font(.caption).foregroundColor(.gray) }
                        }
                        Spacer()
                        if league.rawValue < currentLeague.rawValue { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        else if league.rawValue > currentLeague.rawValue { Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.5)) }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Droga Ligowa").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Gotowe") { dismiss() } } }
        }
    }
}

struct LeagueCardHeader: View {
    let currentLeague: LeagueType; let timeRemaining: String
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: currentLeague.gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing).cornerRadius(16).shadow(color: currentLeague.gradientColors.first!.opacity(0.3), radius: 8, x: 0, y: 4)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentLeague.title).font(.title3).bold().foregroundColor(.white).shadow(radius: 1)
                    HStack(spacing: 4) { Image(systemName: "clock").font(.caption2); Text(timeRemaining).font(.caption).fontWeight(.semibold).monospacedDigit() }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).cornerRadius(8).foregroundColor(.white)
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: currentLeague.iconName).font(.system(size: 28)).foregroundColor(.white).shadow(radius: 2)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.white.opacity(0.6))
                    ZStack {
                        Circle().fill(.ultraThinMaterial).frame(width: 36, height: 36)
                        if currentLeague.nextLeague != nil { Image(systemName: "lock.fill").font(.caption).foregroundColor(.white.opacity(0.9)) }
                        else { Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow) }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
    }
}

struct PodiumView: View {
    let user: LeaderboardUser; let height: CGFloat; let color: Color; let isVisible: Bool
    var body: some View {
        VStack {
            ZStack {
                Circle().fill(user.avatarColor.opacity(0.2)).frame(width: 55, height: 55)
                Text(String(user.name.prefix(1))).font(.title3).bold().foregroundColor(user.avatarColor)
                if user.rank <= 3 {
                    VStack { Spacer(); HStack { Spacer(); Circle().fill(color).frame(width: 22, height: 22).overlay(Text("\(user.rank)").font(.caption2).bold().foregroundColor(.white)).offset(x: 4, y: 4) } }.frame(width: 55, height: 55)
                }
            }
            .opacity(isVisible ? 1 : 0).offset(y: isVisible ? 0 : 20).animation(.easeOut.delay(0.2), value: isVisible)
            Text(user.name).font(.caption).bold().lineLimit(1).opacity(isVisible ? 1 : 0)
            Text("\(user.xp) XP").font(.caption2).foregroundColor(.gray).opacity(isVisible ? 1 : 0)
            Rectangle().fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.6), color.opacity(0.3)]), startPoint: .top, endPoint: .bottom)).frame(width: 70, height: isVisible ? height : 0).cornerRadius(12, corners: [.topLeft, .topRight])
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RoundedCorner(radius: radius, corners: corners)) }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path { let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)); return Path(path.cgPath) }
}
