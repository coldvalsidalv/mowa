import SwiftUI

struct ReviewSelectionView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // Заголовок
                    VStack(spacing: 8) {
                        Text("Co chcesz powtórzyć?")
                            .font(.largeTitle)
                            .bold()
                        Text("Wybierz tryb powtórki")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Кнопка 1: СЛОВА (SRS)
                    NavigationLink(destination: FlashcardView(categories: [], isReviewMode: true)) {
                        ReviewOptionCard(
                            title: "Słówka",
                            subtitle: "Inteligentna powtórka (SRS)",
                            icon: "textformat.abc",
                            color: .blue
                        )
                    }
                    
                    // Кнопка 2: ГРАММАТИКА (Викторина)
                    NavigationLink(destination: QuizView()) {
                        ReviewOptionCard(
                            title: "Gramatyka",
                            subtitle: "Test wyboru i zasady",
                            icon: "text.book.closed.fill",
                            color: .purple
                        )
                    }
                    
                    // Кнопка 3: МИКС (Пока направим на слова, но можно сделать отдельный режим)
                    NavigationLink(destination: FlashcardView(categories: [], isReviewMode: true)) {
                        ReviewOptionCard(
                            title: "Wszystko",
                            subtitle: "Słowa i gramatyka razem",
                            icon: "shuffle",
                            color: .orange
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct ReviewOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
