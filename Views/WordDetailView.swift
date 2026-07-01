import SwiftUI
import SwiftData

struct WordDetailView: View {
    let word: VocabItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var showResetAlert = false

    private var inflections: [String: String] {
        guard let data = word.inflections.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    // Порядок и названия флексий
    private let inflectionKeys: [(key: String, label: String)] = [
        ("1sg", L("word.infl_1sg")),
        ("3sg", L("word.infl_3sg")),
        ("past", L("word.infl_past")),
        ("imp", L("word.infl_imp")),
        ("gen", L("word.infl_gen")),
        ("pl", L("word.infl_pl")),
        ("fem", L("word.infl_fem")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── Шапка ─────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(statusLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Слово + транскрипция + аудио ──────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(word.polish)
                                .font(.system(size: 36, weight: .bold))

                            if !word.partOfSpeech.isEmpty {
                                Text(word.partOfSpeech)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundColor(.orange)
                                    .cornerRadius(6)
                            }
                        }

                        Spacer()

                        Button {
                            SpeechService.shared.speak(word)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(14)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    Divider()

                    // ── Перевод ───────────────────────────────────────────
                    Text(word.translation)
                        .font(.system(size: 28, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)

                    // ── Пример ────────────────────────────────────────────
                    if !word.example.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("flashcard.example"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                Text(word.example)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }

                    // ── Флексии ───────────────────────────────────────────
                    if !inflections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("word.forms_header"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(inflectionKeys.filter { inflections[$0.key] != nil }, id: \.key) { item in
                                    HStack {
                                        Text(item.label)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .frame(width: 110, alignment: .leading)
                                        Text(inflections[item.key]!)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)

                                    if item.key != inflectionKeys.last(where: { inflections[$0.key] != nil })?.key {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }

            Divider()

            // ── Действия ──────────────────────────────────────────────────
            VStack(spacing: 0) {
                actionRow(icon: "arrow.counterclockwise", label: L("word.reset_action"), color: .primary) {
                    showResetAlert = true
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onDisappear { SpeechService.shared.stop() }
        .alert(L("word.reset_title"), isPresented: $showResetAlert) {
            Button(L("word.reset_confirm"), role: .destructive) { resetProgress() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("word.reset_message"))
        }
    }

    // MARK: - Helpers

    private func actionRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 22)
                Text(label)
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
    }

    private func resetProgress() {
        word.fsrsData.state = .new
        word.fsrsData.stability = 0
        word.fsrsData.difficulty = 0
        word.fsrsData.reps = 0
        word.fsrsData.lapses = 0
        word.fsrsData.lastReview = nil
        word.fsrsData.due = Date()
        try? modelContext.save()
    }

    private var statusLabel: String {
        switch word.fsrsData.state {
        case .new:                          return L("word.status_new")
        case .learning, .relearning:        return L("word.status_learning")
        case .review where word.fsrsData.stability >= 21: return L("word.status_mastered")
        case .review:                       return L("word.status_known")
        }
    }

    private var statusColor: Color {
        switch word.fsrsData.state {
        case .new:                          return .secondary
        case .learning, .relearning:        return .orange
        case .review where word.fsrsData.stability >= 21: return .green
        case .review:                       return .blue
        }
    }
}
