import SwiftUI
import SwiftData

/// Карточка подготовки к экзамену на главном экране: обратный отсчёт + дневной
/// план + CTA на сессию слов целевого уровня. Аддитивна — обычные темы не трогает.
struct ExamCard: View {
    @ObservedObject var store: ExamPlanStore
    let onSetup: () -> Void
    let onStart: (ExamLevel) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var remainingNew: Int = 0

    var body: some View {
        Group {
            if store.isConfigured, let level = store.targetLevel, let days = store.daysLeft {
                configuredCard(level: level, days: days)
            } else {
                setupPrompt
            }
        }
        .padding(.horizontal)
        .onAppear(perform: refreshRemaining)
        // Словарь сидится асинхронно (VocabSyncService) — на первом запуске
        // onAppear считает остаток до сидинга. Пересчитываем по сигналу.
        .onReceive(NotificationCenter.default.publisher(for: .vocabularyDidChange)) { _ in
            refreshRemaining()
        }
    }

    // MARK: - States

    private var setupPrompt: some View {
        Button(action: onSetup) {
            HStack(spacing: 16) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2).foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.2)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("exam.setup_title")).font(.headline).foregroundColor(.white)
                    Text(L("exam.setup_sub")).font(.caption).foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(examGradient)
            .cornerRadius(20)
            .shadow(color: .indigo.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func configuredCard(level: ExamLevel, days: Int) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(L("exam.title_fmt", level.title)).font(.headline).foregroundColor(.white)
                        Button(action: onSetup) {
                            Image(systemName: "pencil").font(.caption).foregroundColor(.white.opacity(0.8))
                        }
                    }
                    Text(countdownText(days)).font(.caption).foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(days > 0 ? "\(days)" : (days == 0 ? "0" : "—"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(L("exam.days")).font(.caption2).foregroundColor(.white.opacity(0.8))
                }
            }

            HStack {
                Image(systemName: "calendar.badge.clock").foregroundColor(.white.opacity(0.9))
                Text(planText(days: days)).font(.caption).foregroundColor(.white.opacity(0.9))
                Spacer()
            }

            Button(action: { onStart(level) }) {
                HStack {
                    Text(L("exam.learn_fmt", level.title)).font(.subheadline).bold()
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.indigo)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.white).cornerRadius(14)
            }
        }
        .padding()
        .background(examGradient)
        .cornerRadius(20)
        .shadow(color: .indigo.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    // MARK: - Helpers

    private var examGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 99/255, green: 102/255, blue: 241/255),
                     Color(red: 139/255, green: 92/255, blue: 246/255)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func countdownText(_ days: Int) -> String {
        if days < 0 { return L("exam.past") }
        if days == 0 { return L("exam.today") }
        return L("exam.countdown")
    }

    private func planText(days: Int) -> String {
        guard remainingNew > 0 else { return L("exam.all_done") }
        if days <= 0 { return L("exam.remaining_fmt", remainingNew) }
        let perDay = Int((Double(remainingNew) / Double(days)).rounded(.up))
        return L("exam.per_day_fmt", perDay, remainingNew)
    }

    private func refreshRemaining() {
        guard let level = store.targetLevel else { return }
        let engine = LearningEngine(context: modelContext)
        remainingNew = engine.countRemainingNew(level: level.rawValue)
    }
}

/// Лист настройки цели: уровень + дата (с быстрым выбором официальных сессий).
struct ExamSetupSheet: View {
    @ObservedObject var store: ExamPlanStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var level: ExamLevel
    @State private var date: Date
    @State private var sessions: [ExamSession] = []

    init(store: ExamPlanStore) {
        self.store = store
        _level = State(initialValue: store.targetLevel ?? .b1)
        _date = State(initialValue: store.examDate ?? Date())
    }

    /// Будущие официальные сессии, на которых сдаётся выбранный уровень.
    private var upcomingForLevel: [ExamSession] {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions
            .filter { $0.offers(level) && $0.startDate >= today }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("exam.target_level")) {
                    Picker(L("exam.level"), selection: $level) {
                        ForEach(ExamLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                officialSessionsSection

                Section(L("exam.other_date")) {
                    DatePicker(L("exam.custom_date"), selection: $date, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                if store.isConfigured {
                    Section {
                        Button(L("exam.delete_goal"), role: .destructive) {
                            store.targetLevel = nil
                            store.examDate = nil
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(L("exam.plan_title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                sessions = await DataManager.shared.loadExamSessionsAsync()
                // Без явной даты дефолтим на ближайшую официальную сессию, иначе
                // "Сохранить" без выбора даты записал бы сегодня (daysLeft == 0).
                if store.examDate == nil, let first = upcomingForLevel.first {
                    date = first.startDate
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        store.targetLevel = level
                        store.examDate = date
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var officialSessionsSection: some View {
        Section {
            if upcomingForLevel.isEmpty {
                Text(L("exam.no_sessions_fmt", level.title))
                    .font(.footnote).foregroundColor(.secondary)
            } else {
                ForEach(upcomingForLevel) { session in
                    Button {
                        date = session.startDate
                    } label: {
                        HStack {
                            Text(Self.rangeText(session)).foregroundColor(.primary)
                            Spacer()
                            if Calendar.current.isDate(session.startDate, inSameDayAs: date) {
                                Image(systemName: "checkmark").foregroundColor(.indigo)
                            }
                        }
                    }
                }
            }
        } header: {
            Text(L("exam.official_sessions"))
        } footer: {
            Text(L("exam.sessions_footer"))
        }
    }

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// "27–28 июня 2026". Локаль следует за языком приложения (рантайм-свизл),
    /// а не за локалью устройства.
    private static func rangeText(_ s: ExamSession) -> String {
        let f = rangeFormatter
        f.locale = Locale(identifier: LanguageManager.shared.currentLanguage)
        let endStr = f.string(from: s.endDate)
        let startDay = Calendar.current.component(.day, from: s.startDate)
        // Сессия всегда в одном месяце (сб–вс) — показываем "27–28 <месяц> <год>".
        return "\(startDay)–\(endStr)"
    }
}
