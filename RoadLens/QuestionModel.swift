import Foundation
import SwiftData

@Model
final class QuestionModel {
    var id: UUID
    var topic: String
    var text: String
    var options: [String]
    var correctOptionIndex: Int
    
    init(topic: String, text: String, options: [String], correctOptionIndex: Int) {
        self.id = UUID()
        self.topic = topic
        self.text = text
        self.options = options
        self.correctOptionIndex = correctOptionIndex
    }
}
