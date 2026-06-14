//
//  CameraViewModel.swift
//  RoadLens
//
//  Created by alina on 08.06.2026.
//

import Foundation
import CoreML
import Vision
import AVFoundation
import SwiftData
internal import Combine

class CameraViewModel: ObservableObject {
    var objectWillChange: ObservableObjectPublisher = ObservableObjectPublisher()
    
    @Published var detectedLabel: String = "Знаків не розпізнано"
    @Published var confidence: Float = 0.0
    
    var modelContext: ModelContext?
    private var lastSavedLabel: String?
    private var lastSavedTime: Date = Date.distantPast
    private let saveCooldown: TimeInterval = 5.0

    private var mlModel: RoadSignDetector?

    init() {
        setupModel()
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            mlModel = try RoadSignDetector(configuration: config)
        } catch {
            print("Помилка завантаження моделі: \(error)")
        }
    }

    func classify(pixelBuffer: CVPixelBuffer) {
        guard let mlModel else { return }

        do {
            let output = try mlModel.prediction(image: pixelBuffer)
            let result = parseYOLOOutput(output.var_909)

            DispatchQueue.main.async {
                if let result {
                    self.detectedLabel = result.label
                    self.confidence = result.confidence
                } else {
                    self.detectedLabel = "Знаків не розпізнано"
                    self.confidence = 0
                }
            }
        } catch {
            print("Prediction error: \(error)")
        }
    }

    private let classNames: [String] = [
        "Заборонний знак",
        "Знак небезпеки",
        "Обов'язковий знак",
        "Інший знак"
    ]

    private struct Detection {
        let label: String
        let confidence: Float
    }

    private func parseYOLOOutput(_ output: MLMultiArray) -> Detection? {
        let numClasses = classNames.count
        let numBoxes = 8400

        var best: Detection? = nil
        var bestConf: Float = 0.4

        for i in 0..<numBoxes {
            for c in 0..<numClasses {
                let idx = (4 + c) * numBoxes + i
                let conf = output[idx].floatValue
                if conf > bestConf {
                    bestConf = conf
                    best = Detection(label: classNames[c], confidence: conf)
                }
            }
        }
        return best
    }
}
