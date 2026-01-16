// ==========================================
// FILE PATH: ./KinoTaste Watch/WatchRecommendationView.swift
// ==========================================

import SwiftUI
import SDWebImageSwiftUI

struct WatchRecommendationView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var navPath: NavigationPath
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                if viewModel.isLoading && viewModel.recommendedMovies.isEmpty {
                    ProgressView()
                } else if viewModel.recommendedMovies.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "film").font(.largeTitle)
                        Text("暂无推荐").foregroundColor(.secondary)
                        Button("刷新") { Task { await viewModel.refreshRecommendations(reset: true) } }
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            EmptyView().id("TOP_ANCHOR")
                            
                            VStack(spacing: 15) {
                                // 1. 顶部提示优化
                                if let cat = viewModel.selectedCategory {
                                    Text(cat.name).font(.caption).foregroundColor(.blue)
                                } else {
                                    // 🟢 优化1：修正副标题为“猜你喜欢”
                                    Text("猜你喜欢").font(.caption).foregroundColor(.secondary)
                                }
                                
                                ForEach(viewModel.recommendedMovies) { movie in
                                    // 🟢 优化2：修复点击不准确问题
                                    NavigationLink(value: movie) {
                                        WatchMovieCard(movie: movie)
                                            // 关键修复：强制定义点击热区形状，防止 NavigationLink 在 ScrollView 中热区漂移
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button {
                                    Task { await viewModel.refreshRecommendations(reset: false) }
                                } label: {
                                    if viewModel.isLoading {
                                        ProgressView().scaleEffect(0.5)
                                    } else {
                                        Text("加载更多")
                                    }
                                }
                                .padding(.vertical)
                            }
                            .padding(.top, 4)
                        }
                        .onChange(of: viewModel.selectedCategory) { _, _ in
                            withAnimation { proxy.scrollTo("TOP_ANCHOR", anchor: .top) }
                        }
                    }
                }
            }
            .navigationTitle("推荐")
            .navigationDestination(for: Movie.self) { movie in
                WatchMovieDetailView(movie: movie)
            }
        }
    }
}
