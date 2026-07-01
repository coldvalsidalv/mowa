import SwiftUI
import Combine

struct LeaderboardUser: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let xp: Int
    let avatarColor: Color
    let isCurrentUser: Bool
    var localImage: UIImage? = nil
}

struct LeaderboardView: View {
    @AppStorage(StorageKeys.userXP) private var userXP: Int = 0
    @AppStorage(StorageKeys.userName) private var userName: String = ""

    @ObservedObject private var avatarManager = AvatarManager.shared

    @State private var entries: [RemoteLeaderboardEntry] = []
    @State private var isLoading = false
    @State private var hasError = false
    @State private var podiumsVisible = false
    @State private var timeRemaining: String = "--h --m"
    @State private var selectedUser: LeaderboardUser? = nil
    @State private var showLeagueMap = false
    @State private var currentUserId: String? = nil
    @State private var lastFetchedAt: Date? = nil

    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let avatarColors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]

    var currentLeague: UserLeague {
        UserLeague.determineLeague(for: userXP)
    }

    private func toUser(_ entry: RemoteLeaderboardEntry, rank: Int) -> LeaderboardUser {
        let color = Self.avatarColors[entry.display_name.stableHash % Self.avatarColors.count]
        let isCurrent = entry.user_id == currentUserId
        return LeaderboardUser(
            rank: rank,
            name: entry.display_name,
            xp: entry.xp,
            avatarColor: color,
            isCurrentUser: isCurrent,
            localImage: isCurrent ? avatarManager.avatar : nil
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
                        .padding(.bottom, 8)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                        } else if hasError {
                            errorStateView
                        } else if entries.isEmpty {
                            emptyStateView
                        } else {
                            podiumSection
                            listSection
                        }
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
            .task { await loadLeaderboard() }
            .onReceive(timer) { _ in updateTimeRemaining() }
            .onAppear { updateTimeRemaining() }
        }
    }

    // MARK: - Sections

    private var emptyStateView: some View {
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

    private var errorStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Не удалось загрузить рейтинг")
                .font(.headline)
                .foregroundColor(.secondary)
            Button("Повторить") {
                Task { await loadLeaderboard(force: true) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var podiumSection: some View {
        if entries.count >= 3 {
            HStack(alignment: .bottom, spacing: 16) {
                let silver = toUser(entries[1], rank: 2)
                let gold   = toUser(entries[0], rank: 1)
                let bronze = toUser(entries[2], rank: 3)

                PodiumView(user: silver, height: 130, color: Color(red: 0.75, green: 0.75, blue: 0.75), isVisible: podiumsVisible)
                    .onTapGesture { selectedUser = silver }

                PodiumView(user: gold, height: 170, color: .yellow, isVisible: podiumsVisible)
                    .scaleEffect(1.1)
                    .onTapGesture { selectedUser = gold }

                PodiumView(user: bronze, height: 100, color: Color(red: 0.8, green: 0.5, blue: 0.2), isVisible: podiumsVisible)
                    .onTapGesture { selectedUser = bronze }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { podiumsVisible = true }
            }
        } else if entries.count == 2 {
            let silver = toUser(entries[1], rank: 2)
            let gold   = toUser(entries[0], rank: 1)
            HStack(alignment: .bottom, spacing: 16) {
                PodiumView(user: silver, height: 130, color: Color(red: 0.75, green: 0.75, blue: 0.75), isVisible: podiumsVisible)
                    .onTapGesture { selectedUser = silver }
                PodiumView(user: gold, height: 170, color: .yellow, isVisible: podiumsVisible)
                    .scaleEffect(1.1)
                    .onTapGesture { selectedUser = gold }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { podiumsVisible = true }
            }
        } else if let first = entries.first {
            let user = toUser(first, rank: 1)
            HStack(alignment: .bottom, spacing: 16) {
                PodiumView(user: user, height: 170, color: .yellow, isVisible: podiumsVisible)
                    .scaleEffect(1.1)
                    .onTapGesture { selectedUser = user }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { podiumsVisible = true }
            }
        }
    }

    private var listSection: some View {
        let rest = Array(entries.dropFirst(3))

        return Group {
            if !rest.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rest.enumerated()), id: \.element.id) { idx, entry in
                        let rank = 3 + idx + 1
                        let user = toUser(entry, rank: rank)
                        LeaderboardRow(rank: rank, user: user)
                            .onTapGesture { selectedUser = user }
                        if idx < rest.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Data

    private func loadLeaderboard(force: Bool = false) async {
        if !force, let last = lastFetchedAt, Date().timeIntervalSince(last) < 30 { return }
        currentUserId = KeychainHelper.load(KeychainKeys.userId)
        isLoading = true
        defer { isLoading = false }
        LeaderboardSyncService.shared.syncIfNeeded()
        do {
            var fetched = try await APIClient.shared.fetchLeaderboard()
            // Always show the current user — inject a self-entry if absent from the server's top-N.
            // This happens on first session before LeaderboardSyncService has pushed XP.
            if let uid = currentUserId, !uid.isEmpty, userXP > 0, !userName.isEmpty,
               !fetched.contains(where: { $0.user_id == uid }) {
                let selfEntry = RemoteLeaderboardEntry(id: uid, user_id: uid,
                                                       display_name: userName, xp: userXP)
                let insertIdx = fetched.firstIndex(where: { $0.xp <= userXP }) ?? fetched.count
                fetched.insert(selfEntry, at: insertIdx)
            }
            entries = fetched
            hasError = false
            lastFetchedAt = Date()
        } catch {
            hasError = entries.isEmpty
            verbumLog("⚠️ LeaderboardView: \(error)")
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

// MARK: - LeaderboardRow

struct LeaderboardRow: View {
    let rank: Int
    let user: LeaderboardUser

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .center)

            AvatarView(localImage: user.localImage,
                       name: user.name, color: user.avatarColor, size: 40)

            Text(user.name)
                .font(.subheadline)
                .fontWeight(user.isCurrentUser ? .bold : .regular)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Text("\(user.xp) XP")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(user.isCurrentUser ? .blue : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(user.isCurrentUser ? Color.blue.opacity(0.07) : Color.clear)
    }
}

// MARK: - AVATAR VIEW

struct AvatarView: View {
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
            AvatarView(localImage: user.localImage, name: user.name, color: user.avatarColor, size: 90)
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
            AvatarView(localImage: user.localImage, name: user.name, color: user.avatarColor, size: 55)
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
