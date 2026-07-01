import SwiftUI
import SwiftData

struct WritingTaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var tasks: [WritingTask] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(tasks) { task in
                    NavigationLink(destination: WritingEditorView(task: task, context: modelContext)) {
                        taskRow(task)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L("writing.home_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if tasks.isEmpty { tasks = DataManager.shared.loadWritingTasks() } }
    }

    private func taskRow(_ task: WritingTask) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "envelope.fill")
                .font(.title3).foregroundColor(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.12)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(task.prompt)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(.primary).lineLimit(2)
                Text(L("writing.words_range_fmt", task.level, task.minWords, task.maxWords))
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.4))
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
