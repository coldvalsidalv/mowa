import SwiftUI

struct AchievementsDetailView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        NavigationStack {
            List(achievements) { item in
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.title)
                        .foregroundColor(item.unlocked ? item.color : .gray)
                        .frame(width: 50, height: 50)
                        .background(item.unlocked ? item.color.opacity(0.1) : Color.gray.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline).foregroundColor(item.unlocked ? .primary : .secondary)
                        Text(item.description).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if item.unlocked { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(L("profile.all_achievements"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L("common.close")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
