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
                    Text("Готовишься к экзамену?").font(.headline).foregroundColor(.white)
                    Text("Поставь цель — уровень и дату").font(.caption).foregroundColor(.white.opacity(0.85))
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
                        Text("Экзамен \(level.title)").font(.headline).foregroundColor(.white)
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
                    Text("дней").font(.caption2).foregroundColor(.white.opacity(0.8))
                }
            }

            HStack {
                Image(systemName: "calendar.badge.clock").foregroundColor(.white.opacity(0.9))
                Text(planText(days: days)).font(.caption).foregroundColor(.white.opacity(0.9))
                Spacer()
            }

            Button(action: { onStart(level) }) {
                HStack {
                    Text("Учить \(level.title)").font(.subheadline).bold()
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
        if days < 0 { return "Дата экзамена прошла" }
        if days == 0 { return "Экзамен сегодня — удачи!" }
        return "До экзамена осталось"
    }

    private func planText(days: Int) -> String {
        guard remainingNew > 0 else { return "Все слова уровня пройдены" }
        if days <= 0 { return "Осталось ~\(remainingNew) новых слов" }
        let perDay = Int((Double(remainingNew) / Double(days)).rounded(.up))
        return "~\(perDay) слов в день · осталось \(remainingNew)"
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

    @State private var level: ExamLevel
    @State private var date: Date

    init(store: ExamPlanStore) {
        self.store = store
        _level = State(initialValue: store.targetLevel ?? .b1)
        _date = State(initialValue: store.examDate ?? ExamPlanStore.officialDates.first ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Целевой уровень") {
                    Picker("Уровень", selection: $level) {
                        ForEach(ExamLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Дата экзамена") {
                    DatePicker("Дата", selection: $date, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("Официальные сессии 2026") {
                    ForEach(ExamPlanStore.officialDates, id: \.self) { d in
                        Button {
                            date = d
                        } label: {
                            HStack {
                                Text(d.formatted(date: .long, time: .omitted)).foregroundColor(.primary)
                                Spacer()
                                if Calendar.current.isDate(d, inSameDayAs: date) {
                                    Image(systemName: "checkmark").foregroundColor(.indigo)
                                }
                            }
                        }
                    }
                }

                if store.isConfigured {
                    Section {
                        Button("Удалить цель", role: .destructive) {
                            store.targetLevel = nil
                            store.examDate = nil
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("План экзамена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.targetLevel = level
                        store.examDate = date
                        dismiss()
                    }
                }
            }
        }
    }
}
