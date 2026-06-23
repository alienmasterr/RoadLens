//
//  ContentView.swift
//  RoadLens
//
//  Created by alina on 07.06.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var downloader: ModelDownloader

    var body: some View {
        //        TabView {
        //            MySignsView()
        //                .tabItem {
        //                    Label("Мої знаки", systemImage: "house")
        //                }
        //
        //            CameraView()
        //                .tabItem {
        //                    Label("Камера", systemImage: "camera")
        //                }
        //
        //            TestsView()
        //                .tabItem {
        //                    Label("Тести", systemImage: "book")
        //                }
        //        }
        Group {
            switch downloader.state {
            case .ready:
                MainTabView()
            case .failed(let msg):
                ErrorView(message: msg) {
                    downloader.downloadIfNeeded()
                }
            default:
                DownloadProgressView()
            }
        }
    }
}

struct DownloadProgressView: View {
    @EnvironmentObject var downloader: ModelDownloader

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text(stateText)
                .font(.headline)

            if downloader.state == .downloading {
                ProgressView(value: downloader.progress)
                    .padding(.horizontal, 40)
                Text(String(format: "%.0f%%", downloader.progress * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .padding()
    }

    var stateText: String {
        switch downloader.state {
        case .downloading: return "Завантаження моделі"
        case .unzipping: return "Розпакування"
        case .compiling: return "Підготовка моделі"
        default: return "Зачекайте"
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Спробувати знову", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct MainTabView: View {
    @EnvironmentObject var generativeVM: GenerativeViewModel

    var body: some View {
        TabView {
            MySignsView()
                .tabItem { Label("Мої знаки", systemImage: "house") }
            CameraView()
                .tabItem { Label("Камера", systemImage: "camera") }
            TestsView()
                .tabItem { Label("Тести", systemImage: "book") }
        }
        .onAppear {
            // Не завантажуємо генеративну модель одразу
            // Вона завантажиться тільки коли знак розпізнано
        }
    }
}

#Preview {
    ContentView()
}
