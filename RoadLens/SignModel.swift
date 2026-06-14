import Foundation
import SwiftData

@Model
final class SignModel {
    var id: UUID
    var classOfSign: String
    var timestamp: Date
    var isTestPassed: Bool
    
    
    init(classOfSign: String) {
        self.id = UUID()
        self.classOfSign = classOfSign
        self.timestamp = Date()
        self.isTestPassed = false
    }
}
