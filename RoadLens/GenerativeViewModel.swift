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

    private var encoder: [String: Int] = [:]
    private var decoder: [Int: String] = [:]
    private var bpeRanks: [Pair: Int] = [:]

    struct Pair: Hashable {
        let first: String
        let second: String
    }

    init(downloader: ModelDownloader) {
        self.downloader = downloader
        loadTokenizer()
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
        guard let model = mlModel else {
            loadModel()
            errorMessage = "Модель завантажується..."
            return
        }

        isGenerating = true
        errorMessage = nil

        let prompt =
            "Знак: \(signLabel). Контекст: Загальне значення знака. ### "

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.generate(
                    model: model,
                    prompt: prompt,
                    maxNewTokens: 200
                )
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
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    private func generate(model: MLModel, prompt: String, maxNewTokens: Int)
        throws -> String
    {
        var inputIds = encode(text: prompt)
        let maxSeqLen = 128

        for _ in 0..<maxNewTokens {
            let windowIds = Array(inputIds.suffix(maxSeqLen))
            let paddedIds = padOrTruncate(windowIds, to: maxSeqLen)

            let inputArray = try MLMultiArray(
                shape: [1, maxSeqLen] as [NSNumber],
                dataType: .int32
            )
            for (i, id) in paddedIds.enumerated() {
                inputArray[i] = NSNumber(value: id)
            }

            let inputFeatures = try MLDictionaryFeatureProvider(
                dictionary: [
                    "input_ids": MLFeatureValue(multiArray: inputArray)
                ]
            )
            let output = try model.prediction(from: inputFeatures)

            guard
                let logits = output.featureValue(for: "logits")?.multiArrayValue
            else {
                throw GenerationError.noOutput
            }

            let vocabSize = logits.shape[2].intValue
            let lastTokenOffset = (maxSeqLen - 1) * vocabSize
            var logitValues = [Float](repeating: 0, count: vocabSize)
            for i in 0..<vocabSize {
                logitValues[i] = logits[lastTokenOffset + i].floatValue
            }

            let nextTokenId =
                logitValues.enumerated().max(by: { $0.element < $1.element })?
                .offset ?? 0

            if nextTokenId == 50256 { break }

            inputIds.append(nextTokenId)

            let generated = decode(
                tokens: Array(inputIds.dropFirst(encode(text: prompt).count))
            )
            if generated.filter({ $0 == "}" }).count >= 2 { break }
        }

        let promptTokenCount = encode(text: prompt).count
        let newTokens = Array(inputIds.dropFirst(promptTokenCount))
        return decode(tokens: newTokens)
    }

    private func padOrTruncate(_ ids: [Int], to length: Int) -> [Int] {
        if ids.count >= length {
            return Array(ids.suffix(length))
        }
        return [Int](repeating: 50256, count: length - ids.count) + ids
    }

    private struct ParsedQuestion {
        let question: String
        let options: [String]
        let correctAnswer: String
        let explanation: String
    }

    private func parseCompletion(_ text: String) -> ParsedQuestion {
        guard let jsonStart = text.firstIndex(of: "{"),
            let jsonEnd = text.lastIndex(of: "}")
        else {
            return ParsedQuestion(
                question: text,
                options: [],
                correctAnswer: "",
                explanation: ""
            )
        }

        let jsonString = String(text[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            return ParsedQuestion(
                question: text,
                options: [],
                correctAnswer: "",
                explanation: ""
            )
        }

        return ParsedQuestion(
            question: json["question"] as? String ?? "",
            options: json["options"] as? [String] ?? [],
            correctAnswer: json["correct_answer"] as? String ?? "",
            explanation: json["explanation"] as? String ?? ""
        )
    }

    enum GenerationError: Error {
        case noOutput
        case tokenizationFailed
    }

    private func loadTokenizer() {
        guard
            let vocabURL = Bundle.main.url(
                forResource: "vocab",
                withExtension: "json"
            ),
            let mergesURL = Bundle.main.url(
                forResource: "merges",
                withExtension: "txt"
            )
        else {
            print("vocab.json або merges.txt не знайдено в bundle")
            return
        }

        if let data = try? Data(contentsOf: vocabURL),
            let vocab = try? JSONSerialization.jsonObject(with: data)
                as? [String: Int]
        {
            encoder = vocab
            decoder = Dictionary(uniqueKeysWithValues: vocab.map { ($1, $0) })
        }

        if let mergesText = try? String(contentsOf: mergesURL, encoding: .utf8)
        {
            let lines = mergesText.components(separatedBy: "\n").dropFirst()
            for (rank, line) in lines.enumerated() {
                let parts = line.split(separator: " ")
                if parts.count == 2 {
                    bpeRanks[
                        Pair(first: String(parts[0]), second: String(parts[1]))
                    ] = rank
                }
            }
        }

        print("Токенізатор завантажено: \(encoder.count) токенів")
    }

    private func encode(text: String) -> [Int] {
        var tokens: [Int] = []
        let words = text.components(separatedBy: " ")
        for (i, word) in words.enumerated() {
            let prefixed = (i == 0 ? "" : "Ġ") + word
            let wordTokens = bpeEncode(word: prefixed)
            tokens.append(contentsOf: wordTokens)
        }
        return tokens
    }

    private func bpeEncode(word: String) -> [Int] {
        var chars = word.map { String($0) }
        if chars.isEmpty { return [] }

        while chars.count > 1 {
            var minRank = Int.max
            var minIdx = -1

            for i in 0..<chars.count - 1 {
                let pair = Pair(first: chars[i], second: chars[i + 1])
                if let rank = bpeRanks[pair], rank < minRank {
                    minRank = rank
                    minIdx = i
                }
            }

            if minIdx == -1 { break }

            chars[minIdx] = chars[minIdx] + chars[minIdx + 1]
            chars.remove(at: minIdx + 1)
        }

        return chars.compactMap { encoder[$0] }
    }

    private func decode(tokens: [Int]) -> String {
        let text = tokens.compactMap { decoder[$0] }.joined()
        return text.replacingOccurrences(of: "Ġ", with: " ")
    }
}
