//
//  CameraView.swift
//  RoadLens
//
//  Created by alina on 08.06.2026.
//

import SwiftUI

struct CameraView: View {
    
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
                    CameraRepresentable(viewModel: viewModel)
                        .ignoresSafeArea()

                    VStack(spacing: 4) {
                        Text(viewModel.detectedLabel)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if viewModel.confidence > 0 {
                            Text(String(format: "%.0f%%", viewModel.confidence * 100))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 40)
                }
    }
}

struct CameraRepresentable: UIViewControllerRepresentable {
    let viewModel: CameraViewModel

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.viewModel = viewModel
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

#Preview {
    CameraView()
}
