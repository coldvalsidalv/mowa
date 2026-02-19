import SwiftUI

// MARK: - MODELS

// Добавил модель Лиги
enum LeagueType: String, CaseIterable {
    case bronze = "Liga Brązowa"
    case silver = "Liga Srebrna"
    case gold = "Liga Złota"
    
    var color: Color {
        switch self {
        case .bronze: return .orange
        case .silver: return .gray
        case .gold: return .yellow
        }
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

// MARK: - MAIN VIEW

struct LeaderboardView: View {
    // Состояние для анимации
    @State private var podiumsVisible = false
    // Состояние для вкладок (Рейтинг / Статистика)
    @State private var selectedTab = 0
    
    // Имитация данных
    let currentLeague: LeagueType = .bronze
    let users: [LeaderboardUser] = [
        LeaderboardUser(rank: 1, name: "Anna K.", xp: 2450, avatarColor: .purple, isCurrentUser: false),
        LeaderboardUser(rank: 2, name: "Marek W.", xp: 2100, avatarColor: .blue, isCurrentUser: false),
        LeaderboardUser(rank: 3, name: "Kasia L.", xp: 1950, avatarColor: .pink, isCurrentUser: false),
        LeaderboardUser(rank: 4, name: "Uladzislau", xp: 1840, avatarColor: .green, isCurrentUser: true), // ТЫ
        LeaderboardUser(rank: 5, name: "Piotr Z.", xp: 1600, avatarColor: .orange, isCurrentUser: false),
        LeaderboardUser(rank: 6, name: "Ewa N.", xp: 1450, avatarColor: .red, isCurrentUser: false),
        LeaderboardUser(rank: 7, name: "Tomek S.", xp: 1200, avatarColor: .gray, isCurrentUser: false),
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Фон
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ПЕРЕКЛЮЧАТЕЛЬ (Рейтинг / Статистика)
                    Picker("Tabs", selection: $selectedTab) {
                        Text("Ranking").tag(0)
                        Text("Statystyki").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    
                    if selectedTab == 0 {
                        // === ВКЛАДКА РЕЙТИНГА ===
                        ScrollView {
                            VStack(spacing: 24) {
                                // ЗАГОЛОВОК С ЛИГОЙ
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "shield.fill")
                                        Text(currentLeague.rawValue)
                                    }
                                    .font(.headline)
                                    .foregroundColor(currentLeague.color)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(currentLeague.color.opacity(0.1))
                                    .cornerRadius(20)
                                    
                                    Text("Ranking Tygodnia")
                                        .font(.largeTitle)
                                        .bold()
                                    
                                    Text("Do końca: 2 dni")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 20)
                                
                                // ПОДИУМ (ТОП 3) с Анимацией
                                HStack(alignment: .bottom, spacing: 16) {
                                    // 2-е место
                                    PodiumView(user: users[1], height: 140, color: .gray, isVisible: podiumsVisible)
                                    
                                    // 1-е место
                                    PodiumView(user: users[0], height: 170, color: .yellow, isVisible: podiumsVisible)
                                        .scaleEffect(1.1)
                                        .zIndex(1)
                                    
                                    // 3-е место
                                    PodiumView(user: users[2], height: 120, color: .brown, isVisible: podiumsVisible)
                                }
                                .padding(.horizontal)
                                
                                // СПИСОК ОСТАЛЬНЫХ
                                LazyVStack(spacing: 12) {
                                    ForEach(users.dropFirst(3)) { user in
                                        LeaderboardRow(user: user)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 30)
                            }
                        }
                    } else {
                        // === ВКЛАДКА СТАТИСТИКИ ===
                        StatisticsSubView()
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Liderzy")
            .navigationBarHidden(true)
            .onAppear {
                // Запуск анимации пьедестала
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                    podiumsVisible = true
                }
            }
        }
    }
}

// MARK: - VIEW: ЭКРАН СТАТИСТИКИ

struct StatisticsSubView: View {
    // Имитация дней обучения (1 - учил, 0 - пропустил)
    let activityDays = [1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Карточки общей статистики
                HStack(spacing: 16) {
                    StatCard(title: "Słowa dzisiaj", value: "24", icon: "text.book.closed.fill", color: .blue)
                    StatCard(title: "Dni z rzędu", value: "12", icon: "flame.fill", color: .orange)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Календарь активности
                VStack(alignment: .leading, spacing: 16) {
                    Text("Twoja aktywność")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(0..<28) { index in
                            // Просто логика для раскраски дней для примера
                            let isActive = index < activityDays.count && activityDays[index] == 1
                            let isFuture = index > 20
                            
                            Circle()
                                .fill(isFuture ? Color.gray.opacity(0.1) : (isActive ? Color.green : Color.red.opacity(0.3)))
                                .frame(height: 35)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(isFuture ? .gray : .white)
                                )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                
                // График (простая имитация)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Postęp XP")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(0..<7) { day in
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(day == 6 ? 1.0 : 0.4))
                                    .frame(height: CGFloat([40, 60, 30, 80, 50, 90, 70][day]))
                                Text(["Pn", "Wt", "Śr", "Cz", "Pt", "Sb", "Nd"][day])
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(height: 150)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - КОМПОНЕНТЫ

struct PodiumView: View {
    let user: LeaderboardUser
    let height: CGFloat
    let color: Color
    let isVisible: Bool // Параметр для анимации
    
    var body: some View {
        VStack {
            // Аватар
            ZStack {
                Circle()
                    .fill(user.avatarColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Text(String(user.name.prefix(1)))
                    .font(.title2)
                    .bold()
                    .foregroundColor(user.avatarColor)
                
                // Бейдж с номером места
                if user.rank <= 3 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("\(user.rank)")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.white)
                                )
                                .offset(x: 5, y: 5)
                        }
                    }
                    .frame(width: 60, height: 60)
                }
            }
            // Анимация появления аватара (немного позже столбика)
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
            
            // Столбик пьедестала (РАСТЕТ)
            Rectangle()
                .fill(
                    LinearGradient(gradient: Gradient(colors: [color.opacity(0.6), color.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 80, height: isVisible ? height : 0) // Анимация высоты
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
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(user.isCurrentUser ? .blue : .primary)
                
                // Добавил подпись лиги для красоты
                if user.isCurrentUser {
                    Text("Liga Brązowa")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(user.xp)")
                    .font(.headline)
                    .bold()
                Text("XP")
                    .font(.caption2)
                    .foregroundColor(.gray)
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

// Карточка для статистики
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// Расширение для скругления (оставил твое)
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
