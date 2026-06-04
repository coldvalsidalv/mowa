import SwiftUI
import Combine

struct LeaderboardUser: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let xp: Int
    let avatarColor: Color
    let isCurrentUser: Bool
    var avatarURL: String? = nil
    var localImage: UIImage? = nil
}

struct LeaderboardView: View {
    @AppStorage(StorageKeys.userXP) private var userXP: Int = 0
    @AppStorage(StorageKeys.userName) private var userName: String = ""

    @ObservedObject private var avatarManager = AvatarManager.shared

    @State private var podiumsVisible = false
    @State private var timeRemaining: String = "--h --m"
    @State private var selectedUser: LeaderboardUser? = nil
    @State private var showLeagueMap = false

    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var currentLeague: UserLeague {
        UserLeague.determineLeague(for: userXP)
    }

    var currentUser: LeaderboardUser {
        LeaderboardUser(
            rank: 1,
            name: userName.isEmpty ? "Вы" : userName,
            xp: userXP,
            avatarColor: .blue,
            isCurrentUser: true,
            localImage: avatarManager.avatar
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        Button { showLeagueMap = true } label: {
                            LeagueCardHeader(currentLeague: currentLeague, timeRemaining: timeRemaining)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)

                        // Текущий пользователь на подиуме
                        HStack(alignment: .bottom, spacing: 16) {
                            PodiumView(user: currentUser, height: 170, color: .yellow, isVisible: podiumsVisible)
                                .scaleEffect(1.1)
                                .onTapGesture { selectedUser = currentUser }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 40)
                        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { podiumsVisible = true } }

                        // Empty state — реальные соперники появятся с запуском
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary.opacity(0.4))

                            Text("Соперники появятся скоро")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Когда другие пользователи зарегистрируются,\nты сможешь соревноваться с ними здесь.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Ranking")
            .sheet(item: $selectedUser) { user in
                RivalProfileView(user: user)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showLeagueMap) {
                LeagueMapView(currentLeague: currentLeague)
                    .presentationDetents([.fraction(0.7)])
            }
            .onAppear { updateTimeRemaining() }
            .onReceive(timer) { _ in updateTimeRemaining() }
        }
    }

    private func updateTimeRemaining() {
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.weekday = 1
        components.hour = 20
        components.minute = 0
        guard let nextSunday = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return }
        let diff = calendar.dateComponents([.day, .hour, .minute], from: now, to: nextSunday)
        if let day = diff.day, let hour = diff.hour, let minute = diff.minute {
            timeRemaining = day > 0 ? "\(day)d \(hour)h" : "\(hour)h \(minute)m"
        }
    }
}

// MARK: - AVATAR VIEW
struct AvatarView: View {
    let urlString: String?
    let localImage: UIImage?
    let name: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = localImage {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackView: some View {
        ZStack {
            Color(color.opacity(0.2))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - RIVAL PROFILE
struct RivalProfileView: View {
    let user: LeaderboardUser
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)

            AvatarView(urlString: user.avatarURL, localImage: user.localImage, name: user.name, color: user.avatarColor, size: 90)

            Text(user.name).font(.title2).bold()
            Text("\(user.xp) XP").font(.headline).foregroundColor(.secondary)

            Spacer()

            Button { dismiss() } label: {
                Text("Закрыть")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(Color.blue).cornerRadius(16)
            }
            .padding(.horizontal).padding(.bottom, 20)
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
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - LEAGUE MAP
struct LeagueMapView: View {
    let currentLeague: UserLeague
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(UserLeague.allCases) { league in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(league.gradientColors.first!.opacity(0.2)).frame(width: 50, height: 50)
                            Image(systemName: league.icon).foregroundColor(league.gradientColors.first!).font(.title2)
                        }
                        VStack(alignment: .leading) {
                            Text(league.title).font(.headline)
                                .foregroundColor(league.rawValue <= currentLeague.rawValue ? .primary : .gray)
                            if league.rawValue == currentLeague.rawValue {
                                Text("Текущая лига").font(.caption).foregroundColor(.blue).bold()
                            } else if league.rawValue < currentLeague.rawValue {
                                Text("Пройдено").font(.caption).foregroundColor(.green)
                            } else {
                                Text("Заблокировано").font(.caption).foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        if league.rawValue < currentLeague.rawValue {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        } else if league.rawValue > currentLeague.rawValue {
                            Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Лиги").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}

// MARK: - LEAGUE CARD HEADER
struct LeagueCardHeader: View {
    let currentLeague: UserLeague; let timeRemaining: String
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: currentLeague.gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(16)
                .shadow(color: currentLeague.gradientColors.first!.opacity(0.3), radius: 8, x: 0, y: 4)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentLeague.title).font(.title3).bold().foregroundColor(.white)
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption2)
                        Text(timeRemaining).font(.caption).fontWeight(.semibold).monospacedDigit()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial).cornerRadius(8).foregroundColor(.white)
                }
                Spacer()
                Image(systemName: currentLeague.icon).font(.system(size: 28)).foregroundColor(.white)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
    }
}

// MARK: - PODIUM VIEW
struct PodiumView: View {
    let user: LeaderboardUser; let height: CGFloat; let color: Color; let isVisible: Bool
    var body: some View {
        VStack {
            AvatarView(urlString: user.avatarURL, localImage: user.localImage, name: user.name, color: user.avatarColor, size: 55)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut.delay(0.2), value: isVisible)
            Text(user.name).font(.caption).bold().lineLimit(1).opacity(isVisible ? 1 : 0)
            Text("\(user.xp) XP").font(.caption2).foregroundColor(.gray).opacity(isVisible ? 1 : 0)
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.6), color.opacity(0.3)]), startPoint: .top, endPoint: .bottom))
                .frame(width: 70, height: isVisible ? height : 0)
                .cornerRadius(12, corners: [.topLeft, .topRight])
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
