//
//  ModelDownloader.swift
//  RoadLens
//
//  Created by alina on 22.06.2026.
//

internal import Combine
import CommonCrypto
import CoreML
import Foundation
import ZIPFoundation

class ModelDownloader: ObservableObject {
    @Published var state: DownloadState = .idle
    @Published var progress: Double = 0.0

    enum DownloadState: Equatable {
        case idle
        case downloading
        case unzipping
        case compiling
        case ready
        case failed(String)
    }

    private let zipURL = URL(
        string:
            "https://github.com/alienmasterr/RoadLens/releases/download/v2.0/RoadTestGenerator2.mlpackage.zip"
    )!
    private let expectedSHA256 =
        "28a682c41964349eed4d06aade3d99101e4ac584f88f805fc4b0b8e3f03df829"

    private var progressObservation: NSKeyValueObservation?

    var compiledModelURL: URL? {
        let url = documentsURL.appendingPathComponent(
            "RoadTestGenerator.mlmodelc"
        )
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
            0
        ]
    }

    func downloadIfNeeded() {
        if compiledModelURL != nil {
            state = .ready
            return
        }
        startDownload()
    }

    private func startDownload() {
        state = .downloading
        progress = 0

        let task = URLSession.shared.downloadTask(with: zipURL) {
            [weak self] tempURL, response, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.state = .failed(
                        "Помилка завантаження: \(error.localizedDescription)"
                    )
                }
                return
            }

            guard let tempURL else {
                DispatchQueue.main.async {
                    self.state = .failed("Файл не отримано")
                }
                return
            }

            let namedZipURL = self.documentsURL.appendingPathComponent(
                "downloaded_model.zip"
            )
            try? FileManager.default.removeItem(at: namedZipURL)

            do {
                try FileManager.default.copyItem(at: tempURL, to: namedZipURL)
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(
                        "Не вдалося зберегти файл: \(error.localizedDescription)"
                    )
                }
                return
            }

            guard self.verifySHA256(url: namedZipURL) else {
                DispatchQueue.main.async {
                    self.state = .failed(
                        "Файл пошкоджений (SHA256 не співпадає)"
                    )
                }
                return
            }

            DispatchQueue.main.async { self.state = .unzipping }
            self.unzipAndCompile(from: namedZipURL)
        }

        progressObservation = task.progress.observe(\.fractionCompleted) {
            [weak self] p, _ in
            DispatchQueue.main.async { self?.progress = p.fractionCompleted }
        }

        task.resume()
    }

    private func unzipAndCompile(from zipURL: URL) {
        let unzipDest = documentsURL.appendingPathComponent("mlpackage_temp")
        try? FileManager.default.removeItem(at: unzipDest)

        do {
            try FileManager.default.createDirectory(
                at: unzipDest,
                withIntermediateDirectories: true
            )

            guard let archive = Archive(url: zipURL, accessMode: .read) else {
                DispatchQueue.main.async {
                    self.state = .failed("Не вдалося відкрити архів")
                }
                return
            }

            for entry in archive {
                guard !entry.path.contains("__MACOSX"),
                    !entry.path.hasSuffix(".DS_Store")
                else { continue }

                let destURL = unzipDest.appendingPathComponent(entry.path)

                if entry.type == .directory {
                    try FileManager.default.createDirectory(
                        at: destURL,
                        withIntermediateDirectories: true
                    )
                } else {
                    try FileManager.default.createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    _ = try archive.extract(entry, to: destURL)
                }
            }

        } catch {
            DispatchQueue.main.async {
                self.state = .failed(
                    "Розпакування: \(error.localizedDescription)"
                )
            }
            return
        }

        guard let mlpackageURL = findMLPackage(in: unzipDest) else {
            DispatchQueue.main.async {
                self.state = .failed(".mlpackage не знайдено в архіві")
            }
            return
        }

        DispatchQueue.main.async { self.state = .compiling }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let compiledURL = try MLModel.compileModel(at: mlpackageURL)
                let finalURL = self.documentsURL.appendingPathComponent(
                    "RoadTestGenerator.mlmodelc"
                )
                try? FileManager.default.removeItem(at: finalURL)
                try FileManager.default.moveItem(at: compiledURL, to: finalURL)
                try? FileManager.default.removeItem(at: unzipDest)
                DispatchQueue.main.async { self.state = .ready }
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(
                        "Компіляція: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    private func findMLPackage(in directory: URL) -> URL? {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        else { return nil }

        for case let url as URL in enumerator {
            if url.pathExtension == "mlpackage" {
                return url
            }
        }
        return nil
    }

    private func verifySHA256(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        let computed = hash.map { String(format: "%02x", $0) }.joined()
        print("SHA256: \(computed)")
        return computed == expectedSHA256
    }
}
