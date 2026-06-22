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
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String? = nil

    private var mlModel: MLModel?
    private let downloader: ModelDownloader
    private let tokenizer: BPETokenizer

    init(downloader: ModelDownloader) {
        self.downloader = downloader
        self.tokenizer = BPETokenizer()
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
                    print("Генеративна модель завантажена")
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
        print("Генеративна модель вивантажена")
    }

    func generateQuestion(for signLabel: String) {
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

                if self.tokenizer.isEmpty {
                    throw NSError(domain: "GenerativeModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Токенізатор не знайдено. Додайте vocab.json та merges.txt у Xcode."])
                }

                let engine = LLMEngine(model: model, tokenizer: self.tokenizer)
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
