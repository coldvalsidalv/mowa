import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var manager = StreakManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var isPulsing = false
    var onStartLesson: (() -> Void)? = nil
    
    var backgroundColors: [Color] {
        if manager.hasPracticedToday {
            return [
                Color(red: 15/255, green: 12/255, blue: 41/255),
                Color(red: 48/255, green: 43/255, blue: 99/255),
                Color(red: 36/255, green: 36/255, blue: 62/255)
            ]
        } else {
            return [
                Color(red: 41/255, green: 128/255, blue: 185/255),
                Color(red: 109/255, green: 213/255, blue: 250/255),
                Color(red: 188/255, green: 230/255, blue: 255/255)
            ]
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: manager.hasPracticedToday)
            
            DeterministicParticleCanvas(isFire: manager.hasPracticedToday)
                .ignoresSafeArea()
            
            Circle()
                .fill(manager.hasPracticedToday ? Color.orange.opacity(0.2) : Color.white.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: manager.hasPracticedToday ? -100 : 100, y: -200)
            
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "snowflake")
                            .foregroundColor(manager.hasPracticedToday ? .cyan : .white)
                        Text("\(manager.streakFreezes)")
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
                
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: manager.hasPracticedToday ? [.orange, .clear] : [.white, .clear],
                                center: .center, startRadius: 0, endRadius: 120
                            )
                        )
                        .frame(width: 220, height: 220)
                        .opacity(isPulsing ? 0.6 : 0.2)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                    
                    Image(systemName: manager.hasPracticedToday ? "flame.fill" : "snowflake")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundStyle(
                            manager.hasPracticedToday
                            ? LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: manager.hasPracticedToday ? .orange : .white.opacity(0.5), radius: 30, x: 0, y: 0)
                        .scaleEffect(isPulsing ? 1.05 : 0.95)
                        .transition(.scale.combined(with: .opacity))
                        .id(manager.hasPracticedToday)
                }
                .frame(height: 320)
                
                VStack(spacing: 8) {
                    Text("\(manager.dayStreak)")
                        .font(.system(size: 90, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: manager.hasPracticedToday ? .orange.opacity(0.5) : .blue.opacity(0.5), radius: 15)
                    
                    Text(manager.hasPracticedToday ? L("streak.on_fire") : L("streak.freezing"))
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .kerning(1.5)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    Text(manager.hasPracticedToday ? L("streak.unstoppable") : L("streak.melt"))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 4)
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 20) {
                    Button(action: {
                        dismiss()
                        if !manager.hasPracticedToday {
                            // Небольшая задержка, чтобы UI не дергался при закрытии модального окна
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onStartLesson?()
                            }
                        }
                    }) {
                        Text(manager.hasPracticedToday ? L("streak.cta_done") : L("streak.cta_start"))
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                manager.hasPracticedToday
                                ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color(red: 0, green: 91/255, blue: 234/255), Color(red: 0, green: 198/255, blue: 251/255)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(20)
                            .shadow(color: manager.hasPracticedToday ? .orange.opacity(0.4) : .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// Рендеринг частиц (Оптимизировано для GPU)
struct DeterministicParticleCanvas: View {
    let isFire: Bool
    let particleCount = 40
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                for particleIndex in 0..<particleCount {
                    let seed = Double(particleIndex) * 13.7
                    let randomX = sin(seed)
                    let speed = 40.0 + abs(cos(seed)) * 80.0

                    let timeOffset = now * speed + seed * 100
                    let cycle = timeOffset.truncatingRemainder(dividingBy: size.height)

                    if isFire {
                        let posY = size.height - cycle
                        let posX = (size.width / 2) + randomX * 80.0 + sin(now * 3 + Double(particleIndex)) * 20.0
                        let pSize = 3.0 + abs(sin(seed)) * 5.0
                        let opacity = max(0, posY / size.height)

                        context.opacity = opacity
                        context.fill(Path(ellipseIn: CGRect(x: posX, y: posY, width: pSize, height: pSize)), with: .color(.orange))
                    } else {
                        let posY = cycle
                        let posX = (size.width / 2) + randomX * 150.0 + cos(now * 1.5 + Double(particleIndex)) * 30.0
                        let pSize = 2.0 + abs(cos(seed)) * 4.0
                        let opacity = max(0, 1.0 - (posY / size.height))

                        context.opacity = opacity
                        context.fill(Path(ellipseIn: CGRect(x: posX, y: posY, width: pSize, height: pSize)), with: .color(.white))
                    }
                }
            }
        }
    }
}
