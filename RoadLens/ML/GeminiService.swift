import Foundation

class GeminiService {
    static var apiKey: String {
        return Secrets.geminiAPIKey
    }
    
    struct GeminiRequest: Codable {
        let contents: [Content]
        
        struct Content: Codable {
            let parts: [Part]
        }
        struct Part: Codable {
            let text: String
        }
    }
    
    struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        
        struct Candidate: Codable {
            let content: Content?
        }
        struct Content: Codable {
            let parts: [Part]?
        }
        struct Part: Codable {
            let text: String?
        }
    }
    
    static func generateTest(for signLabel: String) async throws -> (question: String, options: [String], correctAnswer: String, explanation: String) {
        guard apiKey != "YOUR_GEMINI_API_KEY_HERE" else {
            throw NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Будь ласка, вставте свій API ключ у Secrets.swift"])
        }
        
        let prompt = """
        Згенеруй одне тестове питання з правил дорожнього руху України про дорожній знак '\(signLabel)'. 
        Поверни відповідь СУВОРО у форматі JSON без жодного додаткового тексту чи форматування markdown. 
        Структура JSON має бути такою:
        {
          "question": "Текст питання",
          "options": ["Варіант 1", "Варіант 2", "Варіант 3", "Варіант 4"],
          "correct_answer": "Один з варіантів, який є правильним",
          "explanation": "Коротке пояснення, чому це правильно"
        }
        """
        
        let requestBody = GeminiRequest(contents: [
            .init(parts: [.init(text: prompt)])
        ])
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Невідома помилка"
            throw NSError(domain: "Gemini", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Помилка API (\(httpResponse.statusCode)): \(errorText)"])
        }
        
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let text = response.candidates?.first?.content?.parts?.first?.text else {
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Порожня відповідь від Gemini"])
        }
        
        let cleanedText = text.replacingOccurrences(of: "```json", with: "")
                              .replacingOccurrences(of: "```", with: "")
                              .trimmingCharacters(in: .whitespacesAndNewlines)
                              
        guard let jsonData = cleanedText.data(using: .utf8),
              let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let question = jsonDict["question"] as? String,
              let options = jsonDict["options"] as? [String],
              let correctAnswer = jsonDict["correct_answer"] as? String else {
            throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Помилка парсингу JSON від Gemini"])
        }
        
        let explanation = jsonDict["explanation"] as? String ?? ""
        
        return (question, options, correctAnswer, explanation)
    }
}
