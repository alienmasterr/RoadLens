//
//  GenerativeViewModel.swift
//  RoadLens
//
//  Created by alina on 22.06.2026.
//

internal import Combine
import CoreML
import Foundation

class GenerativeViewModel: ObservableObject {
    @Published var generatedQuestion: String = ""
    @Published var generatedOptions: [String] = []
    @Published var correctAnswer: String = ""
    @Published var explanation: String = ""
    @Published var signExplanation: String = ""
    @Published var isGenerating: Bool = false
    @Published var isGeneratingExplanation: Bool = false
    @Published var errorMessage: String? = nil

    private var mlModel: MLModel?
    private let downloader: ModelDownloader
    private var tokenizer: BPETokenizer?

    init(downloader: ModelDownloader) {
        self.downloader = downloader
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let t = BPETokenizer()
            DispatchQueue.main.async {
                self?.tokenizer = t
            }
        }
    }

    func loadModel() {
        guard let url = downloader.compiledModelURL else {
            errorMessage = "Модель не знайдена"
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                let model = try MLModel(contentsOf: url, configuration: config)
                DispatchQueue.main.async {
                    self.mlModel = model
//                    print("модель завантажена")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage =
                        "Помилка завантаження: \(error.localizedDescription)"
                }
            }
        }
    }

    func unloadModel() {
        mlModel = nil
//        print("модель вивантажена")
    }

    func generateSignExplanation(for signLabel: String) {
        guard signExplanation.isEmpty else { return }
        isGeneratingExplanation = true
        signExplanation = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let model: MLModel
                if let existing = self.mlModel {
                    model = existing
                } else if let url = self.downloader.compiledModelURL {
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuAndNeuralEngine
                    model = try MLModel(contentsOf: url, configuration: config)
                    DispatchQueue.main.async { self.mlModel = model }
                } else {
                    throw NSError(domain: "", code: 0, userInfo: nil)
                }
                
                guard let tok = self.tokenizer, !tok.isEmpty else {
                    throw NSError(domain: "", code: 0, userInfo: nil)
                }
                
                let engine = LLMEngine(model: model, tokenizer: tok)
                let prompt = "Знак: \(signLabel)\n<|completion|>\nEXPLANATION:"
                let result = try engine.generate(prompt: prompt, maxNewTokens: 150)
                
                let raw = result.replacingOccurrences(of: "<|completion|>", with: "")
                var finalExplanation = raw.replacingOccurrences(of: prompt, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
                if let questionRange = finalExplanation.range(of: "QUESTION:") {
                    finalExplanation = String(finalExplanation[..<questionRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if finalExplanation.isEmpty {
                    finalExplanation = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                DispatchQueue.main.async {
                    self.signExplanation = finalExplanation
                    self.isGeneratingExplanation = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.signExplanation = "Пояснення від локальної моделі недоступне (завантажте модель)."
                    self.isGeneratingExplanation = false
                }
            }
        }
    }

    func generateQuestion(for signLabel: String) {
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let geminiResult = try await GeminiService.generateTest(for: signLabel)
                
                var localExplanation = ""
                
                do {
                    let model: MLModel
                    if let existing = self.mlModel {
                        model = existing
                    } else if let url = self.downloader.compiledModelURL {
                        let config = MLModelConfiguration()
                        config.computeUnits = .cpuAndNeuralEngine
                        model = try MLModel(contentsOf: url, configuration: config)
                        DispatchQueue.main.async { self.mlModel = model }
                    } else {
                        throw NSError(domain: "", code: 0, userInfo: nil)
                    }
                    
                    if let tok = self.tokenizer, !tok.isEmpty {
                        let engine = LLMEngine(model: model, tokenizer: tok)
                        let prompt = "Знак: \(signLabel)\n<|completion|>\n"
                        let result = try engine.generate(prompt: prompt, maxNewTokens: 150)
                        
                        let raw = result.replacingOccurrences(of: "<|completion|>", with: "")
                        localExplanation = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } catch {
                    print("Локальна модель недоступна або помилка: \(error)")
                }
                
                DispatchQueue.main.async {
                    self.generatedQuestion = geminiResult.question
                    self.generatedOptions = geminiResult.options
                    self.correctAnswer = geminiResult.correctAnswer
                    self.explanation = localExplanation.isEmpty ? geminiResult.explanation : localExplanation
                    self.isGenerating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "\(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }

    func generateQuestionLocal(for signLabel: String) {
        isGenerating = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let model: MLModel
                if let existing = self.mlModel {
                    model = existing
                } else {
                    guard let url = self.downloader.compiledModelURL else {
                        throw NSError(domain: "GenerativeModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Файл моделі не знайдено"])
                    }
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuAndNeuralEngine
                    model = try MLModel(contentsOf: url, configuration: config)
                    DispatchQueue.main.async {
                        self.mlModel = model
                        print("Генеративна модель завантажена")
                    }
                }

                guard let tok = self.tokenizer, !tok.isEmpty else {
                    throw NSError(domain: "GenerativeModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Токенізатор ще завантажується або не знайдено."])
                }

                let engine = LLMEngine(model: model, tokenizer: tok)
                let prompt = "Знак: \(signLabel)\n<|completion|>\nQUESTION: "
                
                let result = try engine.generate(prompt: prompt, maxNewTokens: 400)
                let parsed = self.parseCompletion(result)

                DispatchQueue.main.async {
                    self.generatedQuestion = parsed.question
                    self.generatedOptions = parsed.options
                    self.correctAnswer = parsed.correctAnswer
                    self.explanation = parsed.explanation
                    self.isGenerating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "\(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }

    func generateQuestionGemini(for signLabel: String) {
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let geminiResult = try await GeminiService.generateTest(for: signLabel)
                DispatchQueue.main.async {
                    self.generatedQuestion = geminiResult.question
                    self.generatedOptions = geminiResult.options
                    self.correctAnswer = geminiResult.correctAnswer
                    self.explanation = geminiResult.explanation
                    self.isGenerating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "API : \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }

    func generateFromDataset(for signLabel: String) {
        isGenerating = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = Bundle.main.url(forResource: "dataset", withExtension: "json"),
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Не знайдено dataset.json в проєкті"
                    self.isGenerating = false
                }
                return
            }

            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let matchingLines = lines.filter { $0.contains(signLabel) }
            let selectedLine = matchingLines.randomElement() ?? lines.randomElement()
            
            guard let line = selectedLine,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let completionStr = json["completion"] as? String,
                  let completionData = completionStr.data(using: .utf8),
                  let compJson = try? JSONSerialization.jsonObject(with: completionData) as? [String: Any] else {
                DispatchQueue.main.async {
                    self.errorMessage = "Помилка читання БД"
                    self.isGenerating = false
                }
                return
            }

            DispatchQueue.main.async {
                self.generatedQuestion = compJson["question"] as? String ?? ""
                self.generatedOptions = compJson["options"] as? [String] ?? []
                self.correctAnswer = compJson["correct_answer"] as? String ?? ""
                self.explanation = compJson["explanation"] as? String ?? ""
                self.isGenerating = false
            }
        }
    }

    private struct ParsedQuestion {
        let question: String
        let options: [String]
        let correctAnswer: String
        let explanation: String
    }

    private func parseCompletion(_ text: String) -> ParsedQuestion {
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd = text.lastIndex(of: "}") {
            let jsonString = String(text[jsonStart...jsonEnd])
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return ParsedQuestion(
                    question: json["question"] as? String ?? "",
                    options: json["options"] as? [String] ?? [],
                    correctAnswer: json["correct_answer"] as? String ?? "",
                    explanation: json["explanation"] as? String ?? ""
                )
            }
        }
        
        let raw = text.replacingOccurrences(of: "<|completion|>", with: "")
        var questionText = raw
        var options: [String] = []
        
        if let oRange = raw.range(of: "OPTIONS:") {
            questionText = String(raw[..<oRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let optionsPart = String(raw[oRange.upperBound...])
            let lines = optionsPart.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            for line in lines {
                if line.starts(with: "CORRECT") || line.starts(with: "EXPLANATION") || line.starts(with: "Знак:") { break }
                options.append(line)
            }
        } else if raw.contains("1.") && raw.contains("2.") {
            if let firstOptionRange = raw.range(of: "1.") {
                questionText = String(raw[..<firstOptionRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let optionsPart = String(raw[firstOptionRange.lowerBound...])
                let lines = optionsPart.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                for line in lines {
                    if line.starts(with: "1.") || line.starts(with: "2.") || line.starts(with: "3.") || line.starts(with: "4.") {
                        let cleanOption = line.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                        options.append(String(cleanOption))
                    }
                }
            }
        } else {
            questionText = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let qRange = questionText.range(of: "QUESTION:") {
            questionText = String(questionText[qRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if options.count < 2 {
            options = ["Варіант 1", "Варіант 2", "Варіант 3"]
        }
        
        return ParsedQuestion(
            question: questionText,
            options: options,
            correctAnswer: options.first ?? options[0],
            explanation: ""
        )
    }
}
