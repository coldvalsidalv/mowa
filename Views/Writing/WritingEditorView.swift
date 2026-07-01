import SwiftUI
import SwiftData

struct WritingEditorView: View {
    @StateObject private var viewModel: WritingViewModel
    @ObservedObject private var languageManager = LanguageManager.shared

    init(task: WritingTask, context: ModelContext) {
        _viewModel = StateObject(wrappedValue: WritingViewModel(task: task, context: context))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                taskCard

                if case let .done(feedback) = viewModel.phase {
                    WritingFeedbackView(feedback: feedback)
                    Button {
                        viewModel.phase = .editing
                    } label: {
                        Label(L("writing.new_attempt"), systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                } else {
                    editorArea
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L("writing.editor_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.task.prompt).font(.headline)
            ForEach(viewModel.task.requiredPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill").font(.system(size: 5)).foregroundColor(.indigo).padding(.top, 6)
                    Text(point).font(.subheadline).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var editorArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if viewModel.text.isEmpty {
                    Text("Napisz tutaj swój tekst po polsku…")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 8).padding(.leading, 5)
                }
                TextEditor(text: $viewModel.text)
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)

            HStack {
                Text(L("profile.words_count_fmt", viewModel.wordCount))
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(viewModel.isWithinRange ? .green : .gray)
                Text(L("writing.norm_fmt", viewModel.task.minWords, viewModel.task.maxWords))
                    .font(.caption).foregroundColor(.gray)
                Spacer()
            }

            if case let .failed(message) = viewModel.phase {
                Text(message).font(.caption).foregroundColor(.red)
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                Group {
                    if viewModel.phase == .submitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(L("writing.check"))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .background(viewModel.canSubmit ? Color.indigo : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(14)
            .disabled(!viewModel.canSubmit)
        }
    }
}
