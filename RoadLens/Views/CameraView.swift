//
//  CameraView.swift
//  RoadLens
//
//  Created by alina on 08.06.2026.
//

import SwiftUI
import SwiftData

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
                    CameraRepresentable(viewModel: viewModel)
                        .ignoresSafeArea()

                    if viewModel.isModelLoading {
                        VStack {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                            Text("у моделі нема цілі, тільки шлях")
                                .foregroundStyle(.white)
                                .padding(.top, 8)
                        }
                        .padding(24)
                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxHeight: .infinity, alignment: .center)
                    }

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
            
            if let sign = viewModel.signToConfirm {
                VStack(spacing: 12) {
                    Text(sign)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        Button("Пропустити") {
                            viewModel.cancelSaveSign()
                        }
                        .buttonStyle(.bordered)
                        .tint(.clear)
                        .foregroundStyle(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                        
                        Button("Додати") {
                            viewModel.confirmSaveSign()
                        }
                        .buttonStyle(.bordered)
                        .tint(.clear)
                        .foregroundStyle(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding()
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 120)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: viewModel.signToConfirm)
        .onAppear {
            viewModel.modelContext = modelContext
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
