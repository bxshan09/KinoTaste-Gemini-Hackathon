//
//  ProfileView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SDWebImageSwiftUI
import SwiftData
import StoreKit // 🟢 引入 StoreKit

struct ProfileView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @Query(filter: #Predicate<SavedMovie> { $0.isToWatch },
           sort: [SortDescriptor(\.interactionDate, order: .reverse)])
    private var watchlist: [SavedMovie]
    
    @Query(filter: #Predicate<SavedMovie> { $0.isLiked || $0.isDisliked || $0.isNeutral || $0.isWatched })
    private var seenMovies: [SavedMovie]
    
    @State private var showResetAlert = false
    @State private var showClearCacheAlert = false
    @State private var cacheSize: String = "0 MB"
    @State private var showWatchlistDeck = false
    
    // 🟢 打赏相关
    @StateObject private var tipStore = TipStore.shared
    @State private var showTipJar = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: RatedMoviesView()) {
                        HStack {
                            Image(systemName: "star.square.fill").foregroundColor(.yellow)
                            Text(LocalizedStringKey("已评价影片"))
                                .retroFont(size: 16, bold: true)
                            Spacer()
                            Text("\(seenMovies.count)")
                                .retroFont(size: 14)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: HistoryView()) {
                        HStack {
                            Image(systemName: "clock.fill").foregroundColor(.blue)
                            Text(LocalizedStringKey("观影足迹"))
                                .retroFont(size: 16, bold: true)
                            Spacer()
                            Text("\(seenMovies.count)")
                                .retroFont(size: 14)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    Button(action: { showWatchlistDeck = true }) {
                        HStack {
                            Image(systemName: "bookmark.fill").foregroundColor(.blue)
                            Text(LocalizedStringKey("待看清单"))
                                .retroFont(size: 16, bold: true)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            Text("\(watchlist.count)")
                                .retroFont(size: 14)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text(LocalizedStringKey("设置")).retroFont(size: 14, bold: true)) {
                    Button(action: {
                        calculateCacheSize()
                        showClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash").foregroundColor(.primary)
                            Text(LocalizedStringKey("清除图片缓存"))
                                .retroFont(size: 16)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(cacheSize)
                                .retroFont(size: 12)
                                .foregroundColor(.secondary)
                        }
                    }
                    .alert(LocalizedStringKey("清除图片缓存"), isPresented: $showClearCacheAlert) {
                        Button(LocalizedStringKey("取消"), role: .cancel) { }
                        Button(LocalizedStringKey("确认清除"), role: .destructive) {
                            clearCache()
                        }
                    } message: {
                        Text(LocalizedStringKey("确定要清除所有下载的图片缓存吗？"))
                    }
                    
                    Button(action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise").foregroundColor(.red)
                            Text(LocalizedStringKey("重置口味数据"))
                                .retroFont(size: 16)
                                .foregroundColor(.red)
                        }
                    }
                    .alert(LocalizedStringKey("确定要重置吗？"), isPresented: $showResetAlert) {
                        Button(LocalizedStringKey("取消"), role: .cancel) { }
                        Button(LocalizedStringKey("确定重置"), role: .destructive) {
                            viewModel.resetApp()
                        }
                    } message: {
                        Text(LocalizedStringKey("此操作将清空所有“喜欢/不喜欢”以及“待看清单”的数据，且无法恢复。"))
                    }
                    
                    Button(action: {
                        viewModel.requestReview()
                    }) {
                        HStack {
                            Image(systemName: "hand.thumbsup.fill").foregroundColor(.orange)
                            Text(LocalizedStringKey("给个好评"))
                                .retroFont(size: 16)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // 🟢 新增：打赏区域
                Section {
                    Button(action: { showTipJar = true }) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill") // 咖啡图标
                                .foregroundColor(.brown)
                            Text(LocalizedStringKey("请喝咖啡"))
                                .retroFont(size: 16, bold: true)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    VStack(spacing: 8) {
                        Text("KinoTaste")
                            .retroFont(size: 18, bold: true)
                            .foregroundColor(.primary.opacity(0.8))
                        
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                            .retroFont(size: 12)
                            .foregroundColor(.secondary)
                        
                        Text("Data provided by TMDB")
                            .retroFont(size: 10)
                            .foregroundColor(.tertiaryLabel)
                            .padding(.top, 2)
                        
                        Text("ICP备案号：")
                            .retroFont(size: 10)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle(LocalizedStringKey("我的"))
            .listStyle(.insetGrouped)
            .onAppear {
                calculateCacheSize()
            }
            .fullScreenCover(isPresented: $showWatchlistDeck) {
                WatchlistDeckView(movies: watchlist)
            }
            // 🟢 打赏弹窗
            .sheet(isPresented: $showTipJar) {
                TipJarView(isPresented: $showTipJar)
            }
        }
    }
    
    private func calculateCacheSize() {
        let size = SDImageCache.shared.totalDiskSize()
        cacheSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    private func clearCache() {
        SDImageCache.shared.clearDisk {
            calculateCacheSize()
        }
    }
}

// 🟢 新增：打赏视图
struct TipJarView: View {
    @Binding var isPresented: Bool
    @ObservedObject var store = TipStore.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.92, green: 0.85, blue: 0.55)) // 复古黄
                            .frame(width: 100, height: 100)
                            .shadow(radius: 5)
                        
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.brown)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 10) {
                        Text(LocalizedStringKey("开发不易，请我喝杯咖啡吧"))
                            .retroFont(size: 20, bold: true)
                            .multilineTextAlignment(.center)
                        
                        Text(LocalizedStringKey("您的支持将帮助支付服务器费用"))
                            .retroFont(size: 14)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if store.isLoading {
                        ProgressView()
                            .padding()
                    } else if store.products.isEmpty {
                        // 如果还没配置 IAP，显示占位
                        Text(LocalizedStringKey("暂无商品，请稍后再试"))
                            .retroFont(size: 14)
                            .foregroundColor(.gray)
                    } else {
                        // 商品列表
                        VStack(spacing: 15) {
                            ForEach(store.products) { product in
                                Button(action: {
                                    Task { await store.purchase(product) }
                                }) {
                                    HStack {
                                        Text(iconForProduct(product.id))
                                            .font(.title2)
                                        
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .retroFont(size: 16, bold: true)
                                                .foregroundColor(.primary)
                                            Text(product.description)
                                                .retroFont(size: 12)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(product.displayPrice)
                                            .retroFont(size: 16, bold: true)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.blue)
                                            .cornerRadius(20)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 状态提示
                    switch store.purchaseState {
                    case .success:
                        Text(LocalizedStringKey("🎉 谢谢你的咖啡！"))
                            .retroFont(size: 16, bold: true)
                            .foregroundColor(.green)
                            .transition(.scale)
                    case .failed(let error):
                        Text("😢 \(error)")
                            .retroFont(size: 12)
                            .foregroundColor(.red)
                    case .purchasing:
                        ProgressView()
                    default:
                        EmptyView()
                    }
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Text(LocalizedStringKey("以后再说"))
                            .retroFont(size: 14)
                            .foregroundColor(.gray)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await store.requestProducts()
            }
        }
    }
    
    // 根据 ID 返回 Emoji 图标
    func iconForProduct(_ id: String) -> String {
        if id.contains("small") { return "☕️" }
        if id.contains("medium") { return "🍰" }
        if id.contains("large") { return "🍱" }
        return "🎁"
    }
}

extension Color {
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
}
