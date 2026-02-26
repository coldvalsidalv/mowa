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
    var localImage: UIImage? = nil // Захват локального UIImage
    
    var streak: Int = Int.random(in: 1...50)
    var totalWords: Int = Int.random(in: 500...3000)
    var leagueWords: Int = Int.random(in: 50...200)
}

struct LeaderboardView: View {
    @AppStorage(StorageKeys.userXP) private var userXP: Int = 0
    @AppStorage("userName") private var userName: String = "Uladzislau"
    
    @ObservedObject private var avatarManager = AvatarManager.shared
    
    @State private var podiumsVisible = false
    @State private var timeRemaining: String = "--h --m"
    @State private var selectedUser: LeaderboardUser? = nil
    @State private var showLeagueMap = false
    
    @State private var isPodiumVisible = false
    @State private var isListRowVisible = false
    
    @State private var users: [LeaderboardUser] = []
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var currentLeague: UserLeague {
        UserLeague.determineLeague(for: userXP)
    }
    
    var currentUser: LeaderboardUser? {
        users.first(where: { $0.isCurrentUser })
    }
    
    var isMeVisible: Bool {
        guard let me = currentUser else { return false }
        return me.rank <= 3 ? isPodiumVisible : isListRowVisible
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 1. HEADER
                        Button {
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
                        .onAppear { withAnimation { isPodiumVisible = true } }
                        .onDisappear { withAnimation { isPodiumVisible = false } }
                        
                        // 3. LIST HEADER
                        HStack {
                            Text("Top 30")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        
                        // 4. LIST ITEMS
                        ForEach(users.dropFirst(3)) { user in
                            LeaderboardRow(user: user)
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                                .onTapGesture { openUserProfile(user) }
                                .onAppear {
                                    if user.isCurrentUser { withAnimation { isListRowVisible = true } }
                                }
                                .onDisappear {
                                    if user.isCurrentUser { withAnimation { isListRowVisible = false } }
                                }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
            }
            .navigationTitle("Ranking")
            // 5. STICKY ROW
            .safeAreaInset(edge: .bottom) {
                if let me = currentUser, !isMeVisible {
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
                generateUsers()
                updateTimeRemaining()
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                    podiumsVisible = true
                }
            }
            // Регенерируем список при изменении аватара или имени
            .onChange(of: avatarManager.avatar) { _, _ in generateUsers() }
            .onChange(of: userName) { _, _ in generateUsers() }
            .onReceive(timer) { _ in updateTimeRemaining() }
        }
    }
    
    private func generateUsers() {
        var list = [
            LeaderboardUser(rank: 1, name: "Anna K.", xp: currentLeague.rawValue * 1000 + 1450, avatarColor: .purple, isCurrentUser: false, avatarURL: "https://i.pravatar.cc/150?u=anna"),
            LeaderboardUser(rank: 2, name: "Marek W.", xp: currentLeague.rawValue * 1000 + 1100, avatarColor: .blue, isCurrentUser: false, avatarURL: "https://i.pravatar.cc/150?u=marek"),
            LeaderboardUser(rank: 3, name: "Kasia L.", xp: currentLeague.rawValue * 1000 + 950, avatarColor: .pink, isCurrentUser: false, avatarURL: "https://i.pravatar.cc/150?u=kasia"),
        ]
        
        let me = LeaderboardUser(rank: 0, name: userName, xp: userXP, avatarColor: .green, isCurrentUser: true, localImage: avatarManager.avatar)
        list.append(me)
        
        for i in 4...30 {
            let user = LeaderboardUser(
                rank: 0,
                name: "User \(i)",
                xp: max(0, (currentLeague.rawValue * 1000 + 1000) - (i * 40)),
                avatarColor: [.orange, .red, .gray, .cyan, .mint, .indigo, .brown].randomElement()!,
                isCurrentUser: false,
                avatarURL: "https://i.pravatar.cc/150?u=\(i)"
            )
            list.append(user)
        }
        
        list.sort(by: { $0.xp > $1.xp })
        for (index, _) in list.enumerated() {
            list[index] = LeaderboardUser(
                rank: index + 1,
                name: list[index].name,
                xp: list[index].xp,
                avatarColor: list[index].avatarColor,
                isCurrentUser: list[index].isCurrentUser,
                avatarURL: list[index].avatarURL,
                localImage: list[index].localImage,
                streak: list[index].streak,
                totalWords: list[index].totalWords,
                leagueWords: list[index].leagueWords
            )
        }
        self.users = list
    }
    
    private func openUserProfile(_ user: LeaderboardUser) {
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

// MARK: - COMPONENT: AVATAR VIEW
struct AvatarView: View {
    let urlString: String?
    let localImage: UIImage?
    let name: String
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Group {
            if let uiImage = localImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        fallbackView
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
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
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - STICKY USER ROW
struct StickyUserRow: View {
    let user: LeaderboardUser
    let currentLeague: UserLeague
    
    enum Status {
        case promoting, safe, demoting
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
                
                AvatarView(urlString: user.avatarURL, localImage: user.localImage, name: user.name, color: user.avatarColor, size: 44)
                
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
            
            AvatarView(urlString: user.avatarURL, localImage: user.localImage, name: user.name, color: user.avatarColor, size: 48)
            
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

// MARK: - COMPONENT: RIVAL PROFILE
struct RivalProfileView: View {
    let user: LeaderboardUser
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            VStack(spacing: 8) {
                ZStack {
                    AvatarView(urlString: user.avatarURL, localImage: user.localImage, name: user.name, color: user.avatarColor, size: 90)
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.primary)
                                .colorInvert()
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
                
                Text(user.name).font(.title2).bold()
                
                if user.rank <= 10 {
                    Text("🔥 Walczy o awans")
                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.green.opacity(0.15)).foregroundColor(.green).cornerRadius(8)
                } else if user.rank > 20 {
                    Text("⚠️ Zagrożony spadkiem")
                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.red.opacity(0.15)).foregroundColor(.red).cornerRadius(8)
                } else {
                    Text("🛡️ Bezpieczna pozycja")
                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15)).foregroundColor(.secondary).cornerRadius(8)
                }
            }
            
            Divider().padding(.horizontal)
            
            HStack(alignment: .top, spacing: 0) {
                StatColumn(value: "\(user.streak)", label: "Dni z rzędu", icon: "flame.fill", color: .orange)
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1, height: 40).padding(.top, 10)
                StatColumn(value: "\(user.totalWords)", label: "Znane słowa", icon: "book.closed.fill", color: .blue)
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1, height: 40).padding(.top, 10)
                StatColumn(value: "+\(user.leagueWords)", label: "Nowe (Tydzień)", icon: "chart.line.uptrend.xyaxis", color: .green)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Zamknij")
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
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

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
    let currentLeague: UserLeague; let timeRemaining: String
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: currentLeague.gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing)
                .cornerRadius(16)
                .shadow(color: currentLeague.gradientColors.first!.opacity(0.3), radius: 8, x: 0, y: 4)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentLeague.title).font(.title3).bold().foregroundColor(.white).shadow(radius: 1)
                    HStack(spacing: 4) { Image(systemName: "clock").font(.caption2); Text(timeRemaining).font(.caption).fontWeight(.semibold).monospacedDigit() }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).cornerRadius(8).foregroundColor(.white)
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: currentLeague.icon).font(.system(size: 28)).foregroundColor(.white).shadow(radius: 2)
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
                AvatarView(urlString: user.avatarURL, localImage: user.localImage, name: user.name, color: user.avatarColor, size: 55)
                
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
