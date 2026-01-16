//
//  KinoTaste_WatchApp.swift
//  KinoTaste Watch App
//
//  Created by Boxiang Shan on 2026/1/10.
//

import SwiftUI
import SwiftData
import SDWebImageSwiftUI

@main
struct KinoTaste_Watch_AppApp: App {
    @StateObject var viewModel = AppViewModel()
    
    // 🟢 定义共享的 SwiftData 容器 (与 iOS 端保持一致)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedMovie.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        let cache = SDImageCache.shared
        cache.config.maxDiskSize = 50 * 1024 * 1024
        cache.config.maxMemoryCost = 10 * 1024 * 1024
        cache.config.diskCacheExpireType = .accessDate
        cache.config.maxDiskAge = 60 * 60 * 24 * 7
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !viewModel.hasAgreedPrivacy {
                    WatchPrivacyView(viewModel: viewModel)
                        .zIndex(2)
                } else {
                    WatchContentView()
                        .environmentObject(viewModel)
                        .overlay(
                            Group {
                                if viewModel.showSplash {
                                    WatchSplashView().transition(.opacity)
                                }
                            }
                        )
                }
            }
            .animation(.easeInOut, value: viewModel.hasAgreedPrivacy)
            .animation(.easeInOut, value: viewModel.showSplash)
            .background(WatchContextSetter(viewModel: viewModel))
            // 🟢 注入容器
            .modelContainer(sharedModelContainer)
        }
    }
}

struct WatchContextSetter: View {
    @Environment(\.modelContext) var context
    var viewModel: AppViewModel
    
    var body: some View {
        Color.clear
            .onAppear {
                viewModel.setContext(context)
            }
    }
}

struct WatchPrivacyView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill").font(.title2).foregroundColor(.blue).padding(.top, 10)
                Text("欢迎使用").font(.headline)
                Text("请阅读并同意隐私政策以继续使用。我们仅收集必要的观影偏好用于推荐。").font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
                Link("阅读隐私政策", destination: URL(string: "https://api.kinotaste.online/privacy.html")!).font(.caption2).foregroundColor(.blue)
                Button(action: { withAnimation { viewModel.agreePrivacy() } }) {
                    Text("同意并继续").font(.caption).fontWeight(.bold)
                }
                .tint(.blue).padding(.top, 4).padding(.bottom, 10)
            }
        }
        .background(Color.black)
    }
}
