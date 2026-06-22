import SwiftUI
import SwiftData

struct TestSessionView: View {
    let topic: String
    
    @Query private var allQuestions: [QuestionModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var generativeVM: GenerativeViewModel
    @Query private var signs: [SignModel]
    
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
                    Text("Для цієї теми ще немає питань")
                        .font(.headline)
                        
                    if generativeVM.isGenerating {
                        ProgressView("генеруєм питання")
                    } else {
                        Button("Згенерувати тест") {
                            generativeVM.generateQuestion(for: topic)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if let error = generativeVM.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .onChange(of: generativeVM.isGenerating) { oldValue, newValue in
                    if !newValue && !generativeVM.generatedQuestion.isEmpty {
                        let correctIndex = generativeVM.generatedOptions.firstIndex(of: generativeVM.correctAnswer) ?? 0
                        let newQuestion = QuestionModel(
                            topic: topic,
                            text: generativeVM.generatedQuestion,
                            options: generativeVM.generatedOptions,
                            correctOptionIndex: correctIndex
                        )
                        modelContext.insert(newQuestion)
                        generativeVM.generatedQuestion = ""
                    }
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
                    
                    if generativeVM.isGenerating {
                        ProgressView("ШІ генерує")
                    } else {
                        Button("Згенерувати ще одне питання") {
                            generativeVM.generateQuestion(for: topic)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 10)
                    }
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
        .onChange(of: generativeVM.isGenerating) { oldValue, newValue in
            if !newValue && !generativeVM.generatedQuestion.isEmpty {
                let correctIndex = generativeVM.generatedOptions.firstIndex(of: generativeVM.correctAnswer) ?? 0
                let newQuestion = QuestionModel(
                    topic: topic,
                    text: generativeVM.generatedQuestion,
                    options: generativeVM.generatedOptions,
                    correctOptionIndex: correctIndex
                )
                modelContext.insert(newQuestion)
                generativeVM.generatedQuestion = ""
                if isFinished {
                    isFinished = false
                }
            }
        }
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
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
                selectedOption = nil
            } else {
                isFinished = true
                if score == questions.count {
                    if let signToUpdate = signs.first(where: { $0.classOfSign == topic }) {
                        signToUpdate.isTestPassed = true
                    }
                }
            }
        }
    }
}

#Preview {
    TestSessionView(topic: "Заборонні знаки")
}
