import Foundation

class BPETokenizer {
    private var encoder: [String: Int] = [:]
    private var decoder: [Int: String] = [:]
    private var bpeRanks: [Pair: Int] = [:]
    private var byteToUnicode: [UInt8: String] = [:]

    struct Pair: Hashable {
        let first: String
        let second: String
    }

    var isEmpty: Bool {
        return encoder.isEmpty
    }

    init() {
        loadTokenizer()
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

        // Initialize byte-to-unicode mapping
        var bs: [UInt8] = []
        bs.append(contentsOf: 33...126)
        bs.append(contentsOf: 161...172)
        bs.append(contentsOf: 174...255)
        var cs = bs.map { Int($0) }
        var n = 0
        for b in 0...255 {
            let byte = UInt8(b)
            if !bs.contains(byte) {
                bs.append(byte)
                cs.append(256 + n)
                n += 1
            }
        }
        for (i, b) in bs.enumerated() {
            byteToUnicode[b] = String(UnicodeScalar(cs[i])!)
        }

        print("Токенізатор завантажено: \(encoder.count) токенів")
    }

    func encode(text: String) -> [Int] {
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
        let utf8Bytes = Array(word.utf8)
        let mappedWord = utf8Bytes.compactMap { byteToUnicode[$0] }.joined()
        
        var chars = mappedWord.map { String($0) }
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

    func decode(tokens: [Int]) -> String {
        let text = tokens.compactMap { decoder[$0] }.joined()
        
        // Reverse byteToUnicode
        var unicodeToByte: [String: UInt8] = [:]
        for (k, v) in byteToUnicode { unicodeToByte[v] = k }
        
        var bytes: [UInt8] = []
        for char in text {
            if let byte = unicodeToByte[String(char)] {
                bytes.append(byte)
            }
        }
        
        let decodedStr = String(decoding: bytes, as: UTF8.self)
        return decodedStr.replacingOccurrences(of: "Ġ", with: " ")
    }
}
