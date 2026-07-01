import SwiftUI
import SwiftData

// MARK: - Onboarding coordinator

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

    /// Detects the UI language from iOS system settings
    static func detectedLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "ru"
        if preferred.hasPrefix("uk") { return "uk" }
        if preferred.hasPrefix("en") { return "en" }
        return "ru"
    }

    /// Words marked as familiar get an initial FSRS stability
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

// MARK: - Step 1: Welcome

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

                    Text("Выучи польский язык.\nБыстро и по-настоящему.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                OnboardingPrimaryButton(title: "Начать", action: onNext)

                Text("Займёт 2 минуты")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Step 2: UI language

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
            OnboardingHeader(step: 1, total: 3, title: "Выбери язык", subtitle: "На каком языке тебе объяснять?")

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

            OnboardingPrimaryButton(title: "Далее", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Step 3: Placement test

struct PlacementTestStep: View {
    @Binding var knownIDs: Set<Int>
    let onNext: () -> Void

    @State private var currentIndex = 0
    @State private var cardOffset: CGFloat = 0
    @State private var cardOpacity: Double = 1

    // A1 → A2 → B1, to actually determine the level
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
                title: "Что ты уже знаешь?",
                subtitle: "Пропустим то, что тебе знакомо"
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
                Button("Пропустить") { onNext() }
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
                        Text("Не знаю").font(.subheadline.bold())
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
                        Text("Знаю").font(.subheadline.bold())
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
            Text("Знаешь \(knownIDs.count) из \(Self.testWords.count) слов")
                .font(.title2.bold())
            Text(levelLabel)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            OnboardingPrimaryButton(title: "Далее", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }

    private var levelLabel: String {
        switch knownIDs.count {
        case 0..<4:  return "Начинаем с нуля — это нормально 💪"
        case 4..<8:  return "Уровень A1 — есть база"
        case 8..<12: return "Уровень A2 — хороший старт"
        default:     return "Уровень B1+ — сразу к сложному"
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

// MARK: - Step 4: Daily goal

struct GoalStep: View {
    @Binding var selected: Int
    let onNext: () -> Void

    private let options: [(words: Int, label: String, description: String)] = [
        (5, "Легко", "5 слов · ~5 минут"),
        (10, "Нормально", "10 слов · ~10 минут"),
        (20, "Серьёзно", "20 слов · ~20 минут"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 3, total: 3, title: "Дневная цель", subtitle: "Сколько слов учить каждый день?")

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

            OnboardingPrimaryButton(title: "Далее", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Step 5: Ready

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
                    Text("Готово!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Всё настроено.\nНачинаем учить польский.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            OnboardingPrimaryButton(title: "Начать учить", action: onFinish)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Reusable components

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
