import SwiftUI
import Combine

// MARK: - MODELS

enum LeagueType: Int, CaseIterable {
    case bronze = 0
    case silver = 1
    case gold = 2
    
    var title: String {
        switch self {
        case .bronze: return "Liga Brązowa"
        case .silver: return "Liga Srebrna"
        case .gold: return "Liga Złota"
        }
    }
    
    var iconName: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.fill"
        case .gold: return "crown.fill"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.6, green: 0.4, blue: 0.2)]
        case .silver:
            return [Color(red: 0.8, green: 0.8, blue: 0.85), Color(red: 0.6, green: 0.6, blue: 0.65)]
        case .gold:
            return [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.1)]
        }
    }
    
    var nextLeague: LeagueType? {
        return LeagueType(rawValue: self.rawValue + 1)
    }
}

struct LeaderboardUser: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let xp: Int
    let avatarColor: Color
    let isCurrentUser: Bool
}

// MARK: - MAIN VIEW: RANKING

struct LeaderboardView: View {
    @State private var podiumsVisible = false
    @State private var timeRemaining: String = "--h --m"
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    let currentLeague: LeagueType = .bronze
    
    let users: [LeaderboardUser] = [
        LeaderboardUser(rank: 1, name: "Anna K.", xp: 2450, avatarColor: .purple, isCurrentUser: false),
        LeaderboardUser(rank: 2, name: "Marek W.", xp: 2100, avatarColor: .blue, isCurrentUser: false),
        LeaderboardUser(rank: 3, name: "Kasia L.", xp: 1950, avatarColor: .pink, isCurrentUser: false),
        LeaderboardUser(rank: 4, name: "Uladzislau", xp: 1840, avatarColor: .green, isCurrentUser: true),
        LeaderboardUser(rank: 5, name: "Piotr Z.", xp: 1600, avatarColor: .orange, isCurrentUser: false),
        LeaderboardUser(rank: 6, name: "Ewa N.", xp: 1450, avatarColor: .red, isCurrentUser: false),
        LeaderboardUser(rank: 7, name: "Tomek S.", xp: 1200, avatarColor: .gray, isCurrentUser: false),
        LeaderboardUser(rank: 8, name: "Jacek D.", xp: 1100, avatarColor: .cyan, isCurrentUser: false),
        LeaderboardUser(rank: 9, name: "Ola P.", xp: 1050, avatarColor: .mint, isCurrentUser: false),
        LeaderboardUser(rank: 10, name: "Michał K.", xp: 980, avatarColor: .indigo, isCurrentUser: false),
        LeaderboardUser(rank: 11, name: "Adam B.", xp: 800, avatarColor: .brown, isCurrentUser: false)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    // Используем spacing: 0, чтобы вручную контролировать отступы
                    VStack(spacing: 0) {
                        
                        // 1. КОМПАКТНЫЙ ХЕДЕР
                        LeagueCardHeader(currentLeague: currentLeague, timeRemaining: timeRemaining)
                            .padding(.horizontal)
                            .padding(.top, 0) // Убран отступ сверху
                        
                        // 2. ПОДИУМ
                        // Добавлен padding(.vertical, 30) для воздуха вокруг трибуны
                        HStack(alignment: .bottom, spacing: 16) {
                            if users.count > 1 {
                                PodiumView(user: users[1], height: 140, color: .gray, isVisible: podiumsVisible)
                            }
                            if users.count > 0 {
                                PodiumView(user: users[0], height: 170, color: .yellow, isVisible: podiumsVisible)
                                    .scaleEffect(1.1)
                                    .zIndex(1)
                            }
                            if users.count > 2 {
                                PodiumView(user: users[2], height: 120, color: .brown, isVisible: podiumsVisible)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 40) // БОЛЬШОЙ ОТСТУП СВЕРХУ И СНИЗУ
                        
                        // 3. СПИСОК
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Top 10")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(users.prefix(10).dropFirst(3)) { user in
                                    LeaderboardRow(user: user)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Ranking")
            .onAppear {
                updateTimeRemaining()
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                    podiumsVisible = true
                }
            }
            .onReceive(timer) { _ in updateTimeRemaining() }
        }
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

// MARK: - НОВЫЙ КОМПАКТНЫЙ ХЕДЕР

struct LeagueCardHeader: View {
    let currentLeague: LeagueType
    let timeRemaining: String
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: currentLeague.gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(16)
                .shadow(color: currentLeague.gradientColors.first!.opacity(0.3), radius: 8, x: 0, y: 4)
            
            HStack(alignment: .center) {
                // ЛЕВАЯ ЧАСТЬ: Название и Таймер
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentLeague.title)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                    
                    // Таймер
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(timeRemaining)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                // ПРАВАЯ ЧАСТЬ: Иконки
                HStack(spacing: 8) {
                    Image(systemName: currentLeague.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                        
                        if currentLeague.nextLeague != nil {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - КОМПОНЕНТЫ

struct PodiumView: View {
    let user: LeaderboardUser
    let height: CGFloat
    let color: Color
    let isVisible: Bool
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(user.avatarColor.opacity(0.2))
                    .frame(width: 55, height: 55)
                
                Text(String(user.name.prefix(1)))
                    .font(.title3)
                    .bold()
                    .foregroundColor(user.avatarColor)
                
                if user.rank <= 3 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text("\(user.rank)")
                                        .font(.caption2).bold().foregroundColor(.white)
                                )
                                .offset(x: 4, y: 4)
                        }
                    }
                    .frame(width: 55, height: 55)
                }
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut.delay(0.2), value: isVisible)
            
            Text(user.name)
                .font(.caption)
                .bold()
                .lineLimit(1)
                .opacity(isVisible ? 1 : 0)
            
            Text("\(user.xp) XP")
                .font(.caption2)
                .foregroundColor(.gray)
                .opacity(isVisible ? 1 : 0)
            
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.6), color.opacity(0.3)]), startPoint: .top, endPoint: .bottom))
                .frame(width: 70, height: isVisible ? height : 0)
                .cornerRadius(12, corners: [.topLeft, .topRight])
        }
    }
}

struct LeaderboardRow: View {
    let user: LeaderboardUser
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(user.rank)")
                .font(.headline)
                .foregroundColor(.gray)
                .frame(width: 25)
            
            Circle()
                .fill(user.avatarColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(user.avatarColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(user.isCurrentUser ? .blue : .primary)
                
                if user.isCurrentUser {
                    Text("To ty!")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.8))
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(user.xp)")
                    .font(.headline).bold()
                Text("XP").font(.caption2).foregroundColor(.gray)
            }
        }
        .padding()
        .background(user.isCurrentUser ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(user.isCurrentUser ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
