import SwiftUI

struct WritingFeedbackView: View {
    let feedback: WritingFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            overallCard
            scoresCard
            if !feedback.errors.isEmpty { errorsCard }
            improvedCard
        }
    }

    private var overallCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(feedback.overallPercent) / 100)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(feedback.overallPercent)%").font(.headline).bold().foregroundColor(.white)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(feedback.passedEstimate ? "Сдал бы экзамен" : "Пока не проходной")
                    .font(.headline).foregroundColor(.white)
                Text(feedback.summary).font(.caption).foregroundColor(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: feedback.passedEstimate
                    ? [Color(red: 0, green: 176/255, blue: 155/255), Color(red: 150/255, green: 201/255, blue: 61/255)]
                    : [Color.orange, Color.red.opacity(0.8)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
    }

    private var scoresCard: some View {
        VStack(spacing: 10) {
            scoreRow("Wykonanie zadania", feedback.scores.wykonanieZadania)
            scoreRow("Gramatyka", feedback.scores.poprawnoscGramatyczna)
            scoreRow("Słownictwo", feedback.scores.slownictwo)
            scoreRow("Styl", feedback.scores.styl)
            scoreRow("Ortografia/interpunkcja", feedback.scores.ortografiaInterpunkcja)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func scoreRow(_ title: String, _ value: Int) -> some View {
        let clamped = min(max(value, 0), 4)
        return HStack(spacing: 12) {
            Text(title).font(.subheadline).frame(width: 170, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15)).frame(height: 8)
                    Capsule().fill(color(for: clamped))
                        .frame(width: geo.size.width * CGFloat(clamped) / 4, height: 8)
                }
            }
            .frame(height: 8)
            Text("\(value)/4").font(.caption).fontWeight(.semibold).foregroundColor(.gray)
        }
    }

    private func color(for value: Int) -> Color {
        switch value {
        case 4: return .green
        case 2..<4: return .orange
        default: return .red
        }
    }

    private var errorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ошибки (\(feedback.errors.count))").font(.headline)
            ForEach(feedback.errors.indices, id: \.self) { i in
                let err = feedback.errors[i]
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(err.fragment).strikethrough().foregroundColor(.red)
                        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.gray)
                        Text(err.correction).foregroundColor(.green)
                    }
                    .font(.subheadline)
                    Text(err.explanation).font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var improvedCard: some View {
        DisclosureGroup {
            Text(feedback.improvedVersion)
                .font(.subheadline).foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } label: {
            Label("Образцовый ответ", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundColor(.indigo)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
