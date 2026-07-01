import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: String
    @Environment(\.modelContext) private var modelContext

    @Query private var words: [VocabItem]

    init(category: String) {
        self.category = category
        _words = Query(
            filter: #Predicate<VocabItem> { $0.category == category },
            sort: [SortDescriptor(\.rank)]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    statsRow
                }
                Section("Слова") {
                    ForEach(words) { word in
                        WordRowView(word: word)
                    }
                }
            }

            startButton
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Subviews

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(count: words.filter { $0.fsrsData.state == .new }.count,
                     label: "Новых", color: .secondary)
            Divider().frame(height: 32)
            statCell(count: words.filter { $0.fsrsData.state == .learning || $0.fsrsData.state == .relearning || ($0.fsrsData.state == .review && $0.fsrsData.stability < 3) }.count,
                     label: "Учу", color: .orange)
            Divider().frame(height: 32)
            statCell(count: words.filter { $0.fsrsData.state == .review && $0.fsrsData.stability >= 3 && $0.fsrsData.stability < 21 }.count,
                     label: "Знаю", color: .blue)
            Divider().frame(height: 32)
            statCell(count: words.filter { $0.fsrsData.state == .review && $0.fsrsData.stability >= 21 }.count,
                     label: "Выучено", color: .green)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var startButton: some View {
        NavigationLink(destination: FlashcardView(
            categories: [category],
            isReviewMode: false,
            context: modelContext
        )) {
            Text("Учить")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.orange)
                .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Строка слова

struct WordRowView: View {
    let word: VocabItem
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: 12) {
            // Цветная полоска статуса
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundColor(statusColor)
                Text(word.polish)
                    .font(.headline)
                Text(word.translation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { SpeechService.shared.speak(word) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            WordDetailView(word: word)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var statusLabel: String {
        switch word.fsrsData.state {
        case .new:                          return "Новое"
        case .learning, .relearning:        return "Учу"
        case .review where word.fsrsData.stability >= 21: return "Выучено"
        case .review:                       return "Знаю"
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
