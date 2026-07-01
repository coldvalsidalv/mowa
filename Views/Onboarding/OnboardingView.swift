import SwiftUI
import SwiftData

// MARK: - Координатор онбординга

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(StorageKeys.appLanguage) private var appLanguage = "ru"
    @AppStorage(StorageKeys.dailyGoal) private var dailyGoal = 10

    @State private var step = 0
    @State private var selectedLanguage = OnboardingView.detectedLanguage()
    @State private var selectedGoal = 10
    @State private var knownWordIDs: Set<Int> = []

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            switch step {
            case 0: WelcomeStep(onNext: next)
            case 1: LanguageStep(selected: $selectedLanguage, onNext: next)
            case 2: PlacementTestStep(knownIDs: $knownWordIDs, onNext: next)
            case 3: GoalStep(selected: $selectedGoal, onNext: next)
            case 4: ReadyStep(onFinish: finish)
            default: EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private func next() { step += 1 }

    private func finish() {
        appLanguage = selectedLanguage
        dailyGoal = selectedGoal
        applyPlacementResults()
        hasCompletedOnboarding = true
    }

    /// Определяет язык интерфейса по системным настройкам iOS
    static func detectedLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "ru"
        if preferred.hasPrefix("uk") { return "uk" }
        if preferred.hasPrefix("en") { return "en" }
        return "ru"
    }

    /// Слова, отмеченные как знакомые, получают начальную стабильность FSRS
    private func applyPlacementResults() {
        guard !knownWordIDs.isEmpty else { return }

        let knownPolish = Set(
            PlacementTestStep.testWords
                .filter { knownWordIDs.contains($0.id) }
                .map { $0.polish }
        )

        let descriptor = FetchDescriptor<VocabItem>()
        guard let allWords = try? modelContext.fetch(descriptor) else { return }

        let now = Date()
        for word in allWords where knownPolish.contains(word.polish) {
            word.fsrsData.stability = 7.0
            word.fsrsData.state = .review
            word.fsrsData.reps = 1
            word.fsrsData.due = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        }

        try? modelContext.save()
    }
}

// MARK: - Шаг 1: Welcome

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)

                VStack(spacing: 12) {
                    Text("Verbum")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundColor(.primary)

                    Text(L("onboarding.welcome_tagline"))
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                OnboardingPrimaryButton(title: L("onboarding.start"), action: onNext)

                Text(L("onboarding.takes"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Шаг 2: Язык интерфейса

struct LanguageStep: View {
    @Binding var selected: String
    let onNext: () -> Void

    private let languages: [(code: String, name: String)] = [
        ("ru", "Русский"),
        ("uk", "Українська"),
        ("en", "English"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 1, total: 3, title: L("onboarding.language_title"), subtitle: L("onboarding.language_sub"))

            Spacer()

            VStack(spacing: 12) {
                ForEach(languages, id: \.code) { lang in
                    Button(action: { selected = lang.code }) {
                        HStack {
                            Text(lang.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            if selected == lang.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                        .padding(20)
                        .background(selected == lang.code ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected == lang.code ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            OnboardingPrimaryButton(title: L("onboarding.next"), action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Шаг 3: Placement test

struct PlacementTestStep: View {
    @Binding var knownIDs: Set<Int>
    let onNext: () -> Void

    @State private var currentIndex = 0
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1

    // A1 → A2 → B1, чтобы реально определить уровень
    static let testWords: [(id: Int, polish: String, translation: String)] = [
        (0, "mama", "мама"),
        (1, "dom", "дом"),
        (2, "woda", "вода"),
        (3, "dobry", "хороший"),
        (4, "jeść", "есть / кушать"),
        (5, "kupować", "покупать"),
        (6, "pogoda", "погода"),
        (7, "rozumieć", "понимать"),
        (8, "piękny", "красивый"),
        (9, "samochód", "машина"),
        (10, "zapomnieć", "забыть"),
        (11, "przyzwyczajenie", "привычка"),
        (12, "wyjaśnić", "объяснить"),
        (13, "skomplikowany", "сложный"),
        (14, "przedsiębiorstwo", "предприятие"),
    ]

    private var isFinished: Bool { currentIndex >= Self.testWords.count }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(
                step: 2,
                total: 3,
                title: L("onboarding.placement_title"),
                subtitle: L("onboarding.placement_sub")
            )

            if isFinished {
                finishedView
            } else {
                testCardView
            }
        }
    }

    private var testCardView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(currentIndex + 1) / \(Self.testWords.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(L("onboarding.skip")) { onNext() }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()

            let word = Self.testWords[currentIndex]
            VStack(spacing: 16) {
                Text(word.polish)
                    .font(.system(size: 40, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(word.translation.uppercased())
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
            .padding(.horizontal, 32)
            .offset(x: cardOffset)
            .opacity(cardOpacity)

            Spacer()

            HStack(spacing: 16) {
                Button(action: { respond(known: false) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "xmark").font(.title2.bold())
                        Text(L("onboarding.dont_know")).font(.subheadline.bold())
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
                }

                Button(action: { respond(known: true) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.title2.bold())
                        Text(L("onboarding.know")).font(.subheadline.bold())
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var finishedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)
            Text(L("onboarding.placement_result", knownIDs.count, Self.testWords.count))
                .font(.title2.bold())
            Text(levelLabel)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            OnboardingPrimaryButton(title: L("onboarding.next"), action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }

    private var levelLabel: String {
        switch knownIDs.count {
        case 0..<4:  return L("onboarding.level_zero")
        case 4..<8:  return L("onboarding.level_a1")
        case 8..<12: return L("onboarding.level_a2")
        default:     return L("onboarding.level_b1")
        }
    }

    private func respond(known: Bool) {
        if known { knownIDs.insert(Self.testWords[currentIndex].id) }

        withAnimation(.easeInOut(duration: 0.2)) {
            cardOffset = known ? 60 : -60
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            currentIndex += 1
            cardOffset = known ? -60 : 60
            withAnimation(.easeInOut(duration: 0.2)) {
                cardOffset = 0
                cardOpacity = 1
            }
        }
    }
}

// MARK: - Шаг 4: Дневная цель

struct GoalStep: View {
    @Binding var selected: Int
    let onNext: () -> Void

    private let options: [(words: Int, label: String, description: String)] = [
        (5, L("onboarding.goal_easy"), L("onboarding.goal_easy_sub")),
        (10, L("onboarding.goal_normal"), L("onboarding.goal_normal_sub")),
        (20, L("onboarding.goal_serious"), L("onboarding.goal_serious_sub")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 3, total: 3, title: L("onboarding.goal_title"), subtitle: L("onboarding.goal_sub"))

            Spacer()

            VStack(spacing: 12) {
                ForEach(options, id: \.words) { option in
                    Button(action: { selected = option.words }) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.label).font(.headline).foregroundColor(.primary)
                                Text(option.description).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            if selected == option.words {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                        .padding(20)
                        .background(selected == option.words ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected == option.words ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            OnboardingPrimaryButton(title: L("onboarding.next"), action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Шаг 5: Готов

struct ReadyStep: View {
    let onFinish: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.blue)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            scale = 1.0
                            opacity = 1.0
                        }
                    }

                VStack(spacing: 12) {
                    Text(L("onboarding.ready_title"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text(L("onboarding.ready_sub"))
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            OnboardingPrimaryButton(title: L("onboarding.start_learning"), action: onFinish)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Переиспользуемые компоненты

struct OnboardingHeader: View {
    let step: Int
    let total: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(1...total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.blue : Color.gray.opacity(0.25))
                        .frame(width: i == step ? 24 : 8, height: 8)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.top, 24)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(29)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
        }
    }
}
