//
//  CameraViewModel.swift
//  RoadLens
//
//  Created by alina on 08.06.2026.
//

import AVFoundation
internal import Combine
import CoreImage
import CoreML
import Foundation
import Vision

class CameraViewModel: ObservableObject {
//    var objectWillChange: ObservableObjectPublisher =
//        ObservableObjectPublisher()

    @Published var detectedLabel: String = "Знаків не розпізнано"
    @Published var confidence: Float = 0.0

    private var mlModel: RoadSignDetector?
    private let ciContext = CIContext()
    private var frameCounter = 0

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
        
        frameCounter += 1
        guard frameCounter % 10 == 0 else { return }

        guard
            let resized = resizePixelBuffer(
                pixelBuffer,
                width: 640,
                height: 640
            )
        else {
            print("Не вдалося змінити розмір зображення")
            return
        }

        do {
            let output = try mlModel.prediction(image: resized)
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
        "Інший знак",
    ]

    private struct Detection {
        let label: String
        let confidence: Float
    }

    private func parseYOLOOutput(_ output: MLMultiArray) -> Detection? {
        let numClasses = classNames.count
        let numBoxes = 8400

        var bestLabel: String? = nil
        var bestConf: Float = 0.3

        var maxConfPerClass = [Float](repeating: 0, count: numClasses)

        for i in 0..<numBoxes {
            for c in 0..<numClasses {
                let idx = [0, (4 + c), i] as [NSNumber]
                let conf = output[idx].floatValue
                if conf > maxConfPerClass[c] {
                    maxConfPerClass[c] = conf
                }
                if conf > bestConf {
                    bestConf = conf
                    bestLabel = classNames[c]
                }
            }
        }

        if Int.random(in: 0..<30) == 0 {
            print("Макс confidence по класах:")
            for (i, name) in classNames.enumerated() {
                print(
                    "  \(name): \(String(format: "%.4f", maxConfPerClass[i]))"
                )
            }
            print("  Загальний макс: \(String(format: "%.4f", bestConf))")
        }
        
        print("bestLabel=\(String(describing: bestLabel)), bestConf=\(bestConf)")

        //guard bestConf > 0.3, let label = bestLabel else { return nil }
        guard let label = bestLabel else { return nil }
        return Detection(label: label, confidence: bestConf)
    }

    private func resizePixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX =
            CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let scaleY =
            CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let scaled = ciImage.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY)
        )

        var output: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        CVPixelBufferCreate(
            nil,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &output
        )

        guard let out = output else { return nil }
        ciContext.render(scaled, to: out)
        return out
    }
}
