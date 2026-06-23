import SwiftUI
import SwiftData

struct TestSessionView: View {
    let topic: String
    
    @Query(sort: \QuestionModel.createdAt) private var allQuestions: [QuestionModel]
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
                    Text("ця тема ще не вивчена")
                        .font(.headline)
                        
                    if generativeVM.isGenerating {
                        VStack {
                            ProgressView()
                            Text("генеруємо питання")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button("згенерувати") {
                                generativeVM.generateQuestion(for: topic)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("взяти наявні") {
                                generativeVM.generateFromDataset(for: topic)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    if let error = generativeVM.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            } else if isFinished {
                VStack(spacing: 30) {
                    Text("Тест завершено")
                        .font(.largeTitle.bold())
                    
                    Text("Ваш результат: \(score) з \(questions.count)")
                        .font(.title2)
                    
                    Button("Повернутися") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    if generativeVM.isGenerating {
                        VStack {
                            ProgressView()
                            Text("генеруємо")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 10)
                    } else {
                        HStack(spacing: 12) {
                            Button("генерація питання") {
                                generativeVM.generateQuestion(for: topic)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("З бази даних") {
                                generativeVM.generateFromDataset(for: topic)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 10)
                    }
                }
            } else if currentQuestionIndex < questions.count {
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
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(buttonBackgroundColor(for: index)))
                                .foregroundStyle(buttonForegroundColor(for: index))
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
            } else {
                VStack {
                    ProgressView()
                    Text("Оновлення")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    currentQuestionIndex = questions.count
                    selectedOption = nil
                } else if questions.isEmpty {
                    currentQuestionIndex = 0
                    selectedOption = nil
                }
            }
        }
    }
    
    private func buttonBackgroundColor(for index: Int) -> Color {
        guard let selected = selectedOption else { return Color.gray.opacity(0.1) }
        let question = questions[currentQuestionIndex]
        
        if index == question.correctOptionIndex {
            return .green
        } else if index == selected {
            return .red
        }
        return Color.gray.opacity(0.1)
    }
    
    private func buttonForegroundColor(for index: Int) -> Color {
        guard let selected = selectedOption else { return .primary }
        let question = questions[currentQuestionIndex]
        
        if index == question.correctOptionIndex || index == selected {
            return .white
        }
        return .primary
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
