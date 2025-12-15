import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) var dismiss
    
    // Данные
    @AppStorage("dayStreak") var dayStreak: Int = 1
    @AppStorage("streakFreezes") var streakFreezes: Int = 2
    
    // ЛОГИКА СОСТОЯНИЯ
    @State private var hasPracticedToday: Bool = false
    
    // Анимация
    @State private var isPulsing = false
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    
    let days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    
    // --- ИСПРАВЛЕНИЕ ЦВЕТОВ ---
    var backgroundColors: [Color] {
        if hasPracticedToday {
            // ОГОНЬ: Темно-фиолетовый -> Черный
            return [Color(hex: "0F0c29"), Color(hex: "302b63"), Color(hex: "24243e")]
        } else {
            // ЛЕД: Насыщенный голубой -> Светло-голубой (чтобы белые снежинки были видны)
            return [Color(hex: "2980B9"), Color(hex: "6DD5FA"), Color(hex: "bce6ff")]
        }
    }
    
    var startPoint: UnitPoint {
        .top
    }
    
    var endPoint: UnitPoint {
        .bottom
    }
    
    var body: some View {
        ZStack {
            // 1. ДИНАМИЧЕСКИЙ ФОН
            LinearGradient(
                colors: backgroundColors,
                startPoint: startPoint,
                endPoint: endPoint
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: hasPracticedToday)
            
            // Фоновое свечение
            Circle()
                .fill(hasPracticedToday ? Color.orange.opacity(0.2) : Color.white.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: hasPracticedToday ? -100 : 100, y: -200)
            
            VStack(spacing: 0) {
                // --- ВЕРХНЯЯ ПАНЕЛЬ ---
                HStack {
                    // Индикатор "Заморозок"
                    HStack(spacing: 6) {
                        Image(systemName: "snowflake")
                            .foregroundColor(hasPracticedToday ? .cyan : .white)
                        Text("\(streakFreezes)")
                            .bold()
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                
                Spacer()
                
                // --- ЦЕНТРАЛЬНОЕ ЯДРО ---
                ZStack {
                    // ЧАСТИЦЫ
                    ForEach(particles) { particle in
                        Circle()
                            .fill(hasPracticedToday ? Color.orange : Color.white)
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: particle.x, y: particle.y)
                            .opacity(particle.opacity)
                    }
                    
                    // Свечение ядра
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: hasPracticedToday ? [.orange, .clear] : [.white, .clear],
                                center: .center, startRadius: 0, endRadius: 120
                            )
                        )
                        .frame(width: 220, height: 220)
                        .opacity(isPulsing ? 0.6 : 0.2)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                    
                    // ИКОНКА
                    Image(systemName: hasPracticedToday ? "flame.fill" : "snowflake")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundStyle(
                            hasPracticedToday
                            ? LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(
                            color: hasPracticedToday ? .orange : .white.opacity(0.5),
                            radius: 30, x: 0, y: 0
                        )
                        .scaleEffect(isPulsing ? 1.05 : 0.95)
                        .transition(.scale.combined(with: .opacity))
                        .id(hasPracticedToday)
                }
                .frame(height: 320)
                
                // ТЕКСТЫ
                VStack(spacing: 8) {
                    Text("\(dayStreak)")
                        .font(.system(size: 90, weight: .black, design: .rounded))
                        // ТЕКСТ ТЕПЕРЬ ВСЕГДА БЕЛЫЙ ДЛЯ КОНТРАСТА
                        .foregroundColor(.white)
                        .shadow(color: hasPracticedToday ? .orange.opacity(0.5) : .blue.opacity(0.5), radius: 15)
                    
                    Text(hasPracticedToday ? "ДНЕЙ В ОГНЕ" : "СТРИК ЗАМЕРЗАЕТ")
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundColor(.white) // Белый текст читается лучше на синем
                        .kerning(1.5)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    Text(hasPracticedToday ? "Ты неудержим! 🔥" : "Пройди урок, чтобы растопить лед!")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 4)
                }
                .padding(.bottom, 40)
                
                // --- НИЖНЯЯ ПАНЕЛЬ ---
                VStack(spacing: 20) {
                    // Переключатель (ДЛЯ ТЕСТА)
                    Toggle("Симуляция: Урок пройден?", isOn: $hasPracticedToday)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .foregroundColor(.white)
                        .onChange(of: hasPracticedToday) { _, _ in
                            restartAnimation()
                        }
                    
                    // Кнопка
                    Button(action: {
                        dismiss()
                    }) {
                        Text(hasPracticedToday ? "Отлично!" : "Растопить стрик")
                            .font(.headline)
                            .bold()
                            .foregroundColor(hasPracticedToday ? .white : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                hasPracticedToday
                                ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                // ЛЕД: Кнопка теперь темно-синяя для контраста
                                : LinearGradient(colors: [Color(hex: "005BEA"), Color(hex: "00C6FB")], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(20)
                            .shadow(color: hasPracticedToday ? .orange.opacity(0.4) : .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // --- ЛОГИКА АНИМАЦИИ ---
    func restartAnimation() {
        particles.removeAll()
        timer?.invalidate()
        startAnimation()
    }
    
    func startAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let randomX = CGFloat.random(in: -60...60)
            let randomSize = CGFloat.random(in: 3...7)
            
            if hasPracticedToday {
                // Огонь
                let spark = Particle(x: randomX, y: 40, size: randomSize, opacity: 1, speed: CGFloat.random(in: 2...5))
                particles.append(spark)
            } else {
                // Снег
                let snow = Particle(x: CGFloat.random(in: -120...120), y: -180, size: randomSize, opacity: 0.9, speed: CGFloat.random(in: 2...4))
                particles.append(snow)
            }
            
            updateParticles()
        }
    }
    
    func updateParticles() {
        for i in 0..<particles.count {
            if hasPracticedToday {
                withAnimation(.linear(duration: 0.1)) {
                    particles[i].y -= particles[i].speed * 2
                    particles[i].opacity -= 0.03
                    particles[i].x += CGFloat.random(in: -1...1)
                }
            } else {
                withAnimation(.linear(duration: 0.1)) {
                    particles[i].y += particles[i].speed * 1.5
                    particles[i].x += sin(particles[i].y / 40) * 1.5
                    
                    if particles[i].y > 150 {
                        particles[i].opacity -= 0.03
                    }
                }
            }
        }
        particles.removeAll { $0.opacity <= 0 }
    }
}

// Модели
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
}

// Расширение для HEX цветов
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
