import SwiftUI
import SwiftData

struct TestSessionView: View {
    let topic: String
    
    @Query private var allQuestions: [QuestionModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentQuestionIndex = 0
    @State private var selectedOption: Int? = nil
    @State private var score = 0
    @State private var isFinished = false
    
    var questions: [QuestionModel] {
        allQuestions.filter { $0.topic == topic }
    }
    
    var body: some View {
        VStack {
            if questions.isEmpty {
                VStack(spacing: 20) {
                    Text("Для цієї теми ще немає питань.")
                        .font(.headline)
                    Button("Додати демонстраційні питання") {
                        seedSampleData()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if isFinished {
                VStack(spacing: 30) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.yellow)
                    
                    Text("Тест завершено!")
                        .font(.largeTitle.bold())
                    
                    Text("Ваш результат: \(score) з \(questions.count)")
                        .font(.title2)
                    
                    Button("Повернутися") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                let currentQuestion = questions[currentQuestionIndex]
                
                VStack(alignment: .leading, spacing: 20) {
                    ProgressView(value: Double(currentQuestionIndex + 1), total: Double(questions.count))
                        .padding(.top)
                    
                    Text("Питання \(currentQuestionIndex + 1) з \(questions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(currentQuestion.text)
                        .font(.title3.bold())
                        .padding(.vertical)
                    
                    VStack(spacing: 12) {
                        ForEach(0..<currentQuestion.options.count, id: \.self) { index in
                            Button {
                                if selectedOption == nil {
                                    selectedOption = index
                                    if index == currentQuestion.correctOptionIndex {
                                        score += 1
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(currentQuestion.options[index])
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if let selected = selectedOption {
                                        if index == currentQuestion.correctOptionIndex {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        } else if index == selected {
                                            Image(systemName: "x.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(buttonBorderColor(for: index), lineWidth: 2)
                                        .background(buttonBackgroundColor(for: index).cornerRadius(12))
                                )
                                .foregroundStyle(.primary)
                            }
                            .disabled(selectedOption != nil)
                        }
                    }
                    
                    Spacer()
                    
                    if selectedOption != nil {
                        Button {
                            nextQuestion()
                        } label: {
                            Text(currentQuestionIndex + 1 < questions.count ? "Наступне питання" : "Завершити")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
            }
        }
        .navigationTitle(topic)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func buttonBorderColor(for index: Int) -> Color {
        guard let selected = selectedOption else { return Color.gray.opacity(0.3) }
        let question = questions[currentQuestionIndex]
        
        if index == question.correctOptionIndex {
            return .green
        } else if index == selected {
            return .red
        }
        return Color.gray.opacity(0.3)
    }
    
    private func buttonBackgroundColor(for index: Int) -> Color {
        guard let selected = selectedOption else { return Color.clear }
        let question = questions[currentQuestionIndex]
        
        if index == question.correctOptionIndex {
            return .green.opacity(0.1)
        } else if index == selected {
            return .red.opacity(0.1)
        }
        return Color.clear
    }
    
    private func nextQuestion() {
        withAnimation {
            if currentQuestionIndex + 1 < questions.count {
                currentQuestionIndex += 1
                selectedOption = nil
            } else {
                isFinished = true
            }
        }
    }
    
    private func seedSampleData() {
        let sampleQuestions = [
            QuestionModel(topic: "Заборонні знаки", 
                          text: "Що означає знак 'Рух заборонено'?", 
                          options: ["Забороняє рух усіх транспортних засобів", "Забороняє в'їзд", "Забороняє зупинку"], 
                          correctOptionIndex: 0),
            QuestionModel(topic: "Заборонні знаки", 
                          text: "Чи дозволено рух під знак 'Цегла' (В'їзд заборонено) маршрутним таксі?", 
                          options: ["Так", "Ні", "Тільки за спеціальним дозволом"], 
                          correctOptionIndex: 1),
            QuestionModel(topic: "Знак небезпеки", 
                          text: "Яка дистанція має бути між авто під знак 'Обмеження дистанції'?", 
                          options: ["Не менше вказаної", "Не більше вказаної", "Рівно 50 метрів"], 
                          correctOptionIndex: 0)
        ]
        
        for q in sampleQuestions {
            modelContext.insert(q)
        }
    }
}

#Preview {
    TestSessionView(topic: "Заборонні знаки")
}
