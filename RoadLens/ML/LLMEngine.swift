import Foundation
import CoreML

class LLMEngine {
    private let model: MLModel
    private let tokenizer: BPETokenizer
    
    enum GenerationError: Error {
        case noOutput
        case tokenizationFailed
    }
    
    init(model: MLModel, tokenizer: BPETokenizer) {
        self.model = model
        self.tokenizer = tokenizer
    }
    
    func generate(prompt: String, maxNewTokens: Int = 400) throws -> String {
        var inputIds = tokenizer.encode(text: prompt)
        print("LMSys: Prompt tokens: \(inputIds)")
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
                print("LMSys: не знайдено logits у виході моделі")
                throw GenerationError.noOutput
            }

            let vocabSize = logits.shape[2].intValue
            let actualSeqLen = windowIds.count
            let lastTokenOffset = (actualSeqLen - 1) * vocabSize
            var logitValues = [Float](repeating: 0, count: vocabSize)
            for i in 0..<vocabSize {
                logitValues[i] = logits[lastTokenOffset + i].floatValue
            }

            let nextTokenId = sampleLogits(logitValues, temperature: 0.7, topK: 10)

            print("LMSys: згенеровано токен ID \(nextTokenId)")

            if nextTokenId == 50256 { 
                print("LMSys: зупинка")
                break
            }

            inputIds.append(nextTokenId)

            let generated = tokenizer.decode(
                tokens: Array(inputIds.dropFirst(tokenizer.encode(text: prompt).count))
            )
            print("LMSys: поточний згенерований текст: \(generated)")
            
            if generated.filter({ $0 == "}" }).count >= 2 { break }
        }

        let promptTokenCount = tokenizer.encode(text: prompt).count
        let newTokens = Array(inputIds.dropFirst(promptTokenCount))
        return tokenizer.decode(tokens: newTokens)
    }

    private func sampleLogits(_ logits: [Float], temperature: Float, topK: Int) -> Int {
        let tempLogits = logits.map { $0 / temperature }
        
        let enumerated = tempLogits.enumerated()
        let sortedLogits = enumerated.sorted { $0.element > $1.element }
        let topKLogits = Array(sortedLogits.prefix(topK))
        
        let maxLogit = topKLogits.first?.element ?? 0
        let expLogits = topKLogits.map { exp($0.element - maxLogit) }
        let sumExp = expLogits.reduce(0, +)
        let probabilities = expLogits.map { $0 / sumExp }
        
        let randomValue = Float.random(in: 0..<1)
        var cumulative: Float = 0
        for (i, prob) in probabilities.enumerated() {
            cumulative += prob
            if randomValue <= cumulative {
                return topKLogits[i].offset
            }
        }
        return topKLogits.first?.offset ?? 0
    }

    private func padOrTruncate(_ ids: [Int], to length: Int) -> [Int] {
        if ids.count >= length {
            return Array(ids.suffix(length))
        }
        return ids + [Int](repeating: 50256, count: length - ids.count)
    }
}
