//
//  KinoTasteApp.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SwiftData
import SDWebImageSwiftUI

@main
struct KinoTasteApp: App {
    @StateObject var viewModel = AppViewModel()
    
    // 🟢 定义共享的 SwiftData 容器
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedMovie.self,
        ])
        
        // 🟢 CloudKit 配置：
        // 只要 Xcode 中开启了 iCloud Capability，这个默认配置就会尝试同步。
        // isStoredInMemoryOnly: false 确保数据持久化到磁盘
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // SDWebImage 缓存配置
        let cache = SDImageCache.shared
        cache.config.maxDiskSize = 100 * 1024 * 1024
        cache.config.maxMemoryCost = 20 * 1024 * 1024
        cache.config.diskCacheExpireType = .accessDate
        cache.config.maxDiskAge = 60 * 60 * 24 * 7
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if !viewModel.hasAgreedPrivacy {
                    PrivacyAgreementView(viewModel: viewModel)
                        .zIndex(3.0)
                        .transition(.opacity)
                } else {
                    Group {
                        if viewModel.appState == .onboarding {
                            OnboardingView(viewModel: viewModel)
                        } else {
                            MainView(viewModel: viewModel)
                                .environmentObject(viewModel)
                        }
                    }
                    
                    if viewModel.showSplash {
                        SplashView()
                            .transition(.opacity)
                            .zIndex(2.0)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: viewModel.showSplash)
            .animation(.easeInOut(duration: 0.3), value: viewModel.hasAgreedPrivacy)
            .background(ContextSetter(viewModel: viewModel))
            // 🟢 注入配置好的容器
            .modelContainer(sharedModelContainer)
        }
    }
}

// ... 辅助视图代码保持不变 ...
struct ContextSetter: View {
    @Environment(\.modelContext) var context
    var viewModel: AppViewModel
    
    var body: some View {
        Color.clear
            .onAppear {
                viewModel.setContext(context)
            }
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

struct PrivacyAgreementView: View {
    @ObservedObject var viewModel: AppViewModel
    private let privacyURL = URL(string: "https://api.kinotaste.online/privacy.html")!
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60)).foregroundColor(.blue).padding(.bottom, 10)
                Text("欢迎使用今天看什么").font(.title2.bold())
                VStack(spacing: 8) {
                    Text("在开始探索电影世界之前，请您仔细阅读并同意我们的隐私政策。").font(.body).multilineTextAlignment(.center).foregroundColor(.secondary)
                    Text("我们将严格保护您的个人信息安全，仅在您同意的情况下收集必要的观影偏好数据以提供推荐服务。").font(.caption).multilineTextAlignment(.center).foregroundColor(.gray)
                }
                .padding(.horizontal, 30)
                Link("《隐私政策》", destination: privacyURL).font(.headline).foregroundColor(.blue).padding(.vertical, 10)
                Spacer()
                Button(action: { withAnimation { viewModel.agreePrivacy() } }) {
                    Text("同意并继续").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(16).shadow(color: .blue.opacity(0.3), radius: 5, y: 3)
                }
                .padding(.horizontal, 24).padding(.bottom, 50)
            }
        }
    }
}
