import SwiftUI

// Модель для участника рейтинга
struct LeaderboardUser: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let xp: Int
    let avatarColor: Color
    let isCurrentUser: Bool
}

struct LeaderboardView: View {
    // Имитация данных (потом это придет с сервера)
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // ЗАГОЛОВОК
                        VStack(spacing: 8) {
                            Text("Liga Brązowa") // Бронзовая лига
                                .font(.headline)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(20)
                            
                            Text("Ranking Tygodnia")
                                .font(.largeTitle)
                                .bold()
                            
                            Text("Do końca: 2 dni")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // ПОДИУМ (ТОП 3)
                        HStack(alignment: .bottom, spacing: 16) {
                            // 2-е место
                            PodiumView(user: users[1], height: 140, color: .gray) // Серебро
                            
                            // 1-е место
                            PodiumView(user: users[0], height: 170, color: .yellow) // Золото
                                .scaleEffect(1.1) // Чуть больше
                                .zIndex(1)
                            
                            // 3-е место
                            PodiumView(user: users[2], height: 120, color: .brown) // Бронза
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
            }
            .navigationTitle("Liderzy")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - КОМПОНЕНТЫ

struct PodiumView: View {
    let user: LeaderboardUser
    let height: CGFloat
    let color: Color
    
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
            
            Text(user.name)
                .font(.caption)
                .bold()
                .lineLimit(1)
            
            Text("\(user.xp) XP")
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Столбик пьедестала
            Rectangle()
                .fill(
                    LinearGradient(gradient: Gradient(colors: [color.opacity(0.6), color.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 80, height: height) // Высота зависит от места
                .cornerRadius(12, corners: [.topLeft, .topRight])
        }
    }
}

struct LeaderboardRow: View {
    let user: LeaderboardUser
    
    var body: some View {
        HStack(spacing: 16) {
            // Номер
            Text("\(user.rank)")
                .font(.headline)
                .foregroundColor(.gray)
                .frame(width: 30)
            
            // Аватар
            Circle()
                .fill(user.avatarColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(user.avatarColor)
                )
            
            // Имя
            Text(user.name)
                .font(.headline)
                .foregroundColor(user.isCurrentUser ? .blue : .primary)
            
            if user.isCurrentUser {
                Text("(Ty)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // XP
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

// Расширение для скругления конкретных углов (нужно для пьедестала)
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
