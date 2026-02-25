import SwiftUI

struct ReviewSelectionView: View {
    // --- ДАННЫЕ (Заглушки) ---
    // Попробуй поставить 0, чтобы увидеть "Золотую карточку"
    @State var weakWordsCount = 12
    @State var mediumWordsCount = 45
    @State var strongWordsCount = 128
    
    let weakGrammarCount = 3
    let mediumGrammarCount = 8
    let strongGrammarCount = 24
    
    // Общее здоровье памяти
    let memoryHealth: Double = 0.82
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. ХЕДЕР ЗДОРОВЬЯ ПАМЯТИ
                    // padding(.horizontal) добавлен здесь, чтобы ширина совпадала с карточками ниже
                    MemoryHealthHeader(health: memoryHealth)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    // 2. СЕКЦИЯ: СЛОВАРЬ
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(icon: "text.book.closed.fill", title: "Словарь", color: .blue)
                        
                        VStack(spacing: 12) {
                            // Слабые слова
                            NavigationLink(destination: FlashcardView(categories: ["Weak"], isReviewMode: true)) {
                                ReviewCategoryCard(
                                    title: "Слабые слова",
                                    subtitle: "Частые ошибки",
                                    count: weakWordsCount,
                                    icon: "exclamationmark.triangle.fill",
                                    color: .red
                                )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.instance.impact(style: .light)
                            })
                            
                            // Средние слова
                            NavigationLink(destination: FlashcardView(categories: ["Medium"], isReviewMode: true)) {
                                ReviewCategoryCard(
                                    title: "Средние слова",
                                    subtitle: "Нужна практика",
                                    count: mediumWordsCount,
                                    icon: "hourglass",
                                    color: .orange
                                )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.instance.impact(style: .light)
                            })
                            
                            // Сильные слова
                            NavigationLink(destination: FlashcardView(categories: ["Strong"], isReviewMode: true)) {
                                ReviewCategoryCard(
                                    title: "Сильные слова",
                                    subtitle: "Надежно в памяти",
                                    count: strongWordsCount,
                                    icon: "checkmark.circle.fill",
                                    color: .green
                                )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.instance.impact(style: .light)
                            })
                        }
                        .padding(.horizontal)
                    }
                    
                    // 3. СЕКЦИЯ: ГРАММАТИКА
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(icon: "function", title: "Грамматика", color: .purple)
                        
                        VStack(spacing: 12) {
                            // Слабая грамматика
                            NavigationLink(destination: Text("Grammar Weak")) {
                                ReviewCategoryCard(
                                    title: "Сложные правила",
                                    subtitle: "Требуют внимания",
                                    count: weakGrammarCount,
                                    icon: "xmark.octagon.fill",
                                    color: .red
                                )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.instance.impact(style: .light)
                            })
                            
                            // Средняя грамматика
                            NavigationLink(destination: Text("Grammar Medium")) {
                                ReviewCategoryCard(
                                    title: "В процессе",
                                    subtitle: "Иногда путаешь",
                                    count: mediumGrammarCount,
                                    icon: "arrow.triangle.2.circlepath",
                                    color: .orange
                                )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.instance.impact(style: .light)
                            })
                            
                            // Сильная грамматика
                            NavigationLink(destination: Text("Grammar Strong")) {
                                ReviewCategoryCard(
                                    title: "Усвоенные темы",
                                    subtitle: "Закрепление",
                                    count: strongGrammarCount,
                                    icon: "star.fill",
                                    color: .green
                                )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.instance.impact(style: .light)
                            })
                        }
                        .padding(.horizontal)
                    }
                    
                    // Отступ снизу для FAB
                    Spacer(minLength: 100)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // 4. ПЛАВАЮЩАЯ КНОПКА (SMART MIX)
            SmartReviewFAB()
                .padding(.bottom, 20)
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.instance.impact(style: .medium)
                })
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - КОМПОНЕНТ: ХЕДЕР ЗДОРОВЬЯ
struct MemoryHealthHeader: View {
    let health: Double
    
    // Логика цвета "батарейки"
    var healthColor: Color {
        if health > 0.8 { return .green }
        if health > 0.4 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Текстовый заголовок (Выровнен влево)
            VStack(alignment: .leading, spacing: 6) {
                Text("Что повторим?")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Умный алгоритм подобрал слова, которые ты скоро забудешь.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Карточка статистики
            HStack(spacing: 16) {
                // 1. ИКОНКА С ПОДЛОЖКОЙ (Размер 52x52, как у карточек ниже)
                ZStack {
                    Circle()
                        .fill(healthColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundColor(healthColor)
                }
                
                // 2. Прогресс бар и проценты
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Здоровье памяти")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(health * 100))%")
                            .font(.headline)
                            .bold()
                            .foregroundColor(healthColor)
                    }
                    
                    // Линия прогресса
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(healthColor)
                                .frame(width: geo.size.width * health, height: 10)
                        }
                    }
                    .frame(height: 10)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - КОМПОНЕНТ: КАРТОЧКА КАТЕГОРИИ
struct ReviewCategoryCard: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let color: Color
    
    // Логика победы (0 ошибок)
    var isCleared: Bool {
        return count == 0 && (color == .red || color == .orange)
    }
    
    var activeColor: Color { isCleared ? .yellow : color }
    
    var body: some View {
        HStack(spacing: 16) {
            // ИКОНКА С ПОДЛОЖКОЙ (Размер 52x52)
            ZStack {
                Circle()
                    .fill(activeColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: isCleared ? "trophy.fill" : icon)
                    .font(.title3)
                    .foregroundColor(activeColor)
                    .scaleEffect(isCleared ? 1.1 : 1.0)
            }
            
            // ТЕКСТ
            VStack(alignment: .leading, spacing: 3) {
                Text(isCleared ? "Отличная работа!" : title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(isCleared ? "Ошибок нет" : subtitle)
                    .font(.subheadline)
                    .foregroundColor(isCleared ? .orange : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // СЧЕТЧИК
            HStack(spacing: 8) {
                if isCleared {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.yellow)
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(activeColor)
                        
                        Text(count == 1 ? "объект" : "объектов")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                if !isCleared {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: isCleared ? .yellow.opacity(0.2) : .black.opacity(0.04), radius: isCleared ? 8 : 6, x: 0, y: 3)
    }
}

// MARK: - ЗАГОЛОВОК СЕКЦИИ
struct SectionTitle: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            // Центрируем иконку относительно карточек ниже (половина от 52pt = 26pt центр)
            // Иконка в карточке: 52 ширина.
            // Здесь просто ставим отступ, чтобы визуально совпадало
            ZStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            .frame(width: 52, height: 20, alignment: .center) // Ширина совпадает с иконкой карточки
            
            Text(title)
                .font(.title3)
                .bold()
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - FAB (КНОПКА УМНЫЙ МИКС)
struct SmartReviewFAB: View {
    var body: some View {
        NavigationLink(destination: FlashcardView(categories: [], isReviewMode: true)) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text("Умный микс")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        ReviewSelectionView()
    }
}
