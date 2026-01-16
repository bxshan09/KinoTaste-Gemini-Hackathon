//
//  WatchContentView.swift
//  KinoTaste Watch App
//
//  Created by Boxiang Shan on 2026/1/10.
//

import SwiftUI
import SwiftData
import SDWebImageSwiftUI

struct WatchContentView: View {
    @StateObject var viewModel = AppViewModel()
    @Environment(\.modelContext) var modelContext
    @State private var navPath = NavigationPath()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            if viewModel.showSplash {
                WatchSplashView().transition(.opacity)
            } else if viewModel.appState == .onboarding {
                WatchOnboardingView().environmentObject(viewModel).transition(.move(edge: .trailing))
            } else {
                WatchMainTabView(selectedTab: $selectedTab, navPath: $navPath)
                    .environmentObject(viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.showSplash)
        .animation(.easeInOut, value: viewModel.appState)
        .onAppear { viewModel.setContext(modelContext) }
    }
}

// Launch
struct WatchSplashView: View {
    var body: some View {
        ZStack {
            // 底层：全屏海报
            Image("LaunchImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.6) // 稍微压暗一点，因为手表上文字要更清晰
            
            // 上层：文字
            VStack(spacing: 8) {
                Text("今天看什么")
                    .font(.system(size: 20, weight: .heavy, design: .serif))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                
                Text("发现你的下一部电影")
                    .font(.system(size: 11))
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// Main Tab
struct WatchMainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var selectedTab: Int
    @Binding var navPath: NavigationPath
    
    var body: some View {
        TabView(selection: $selectedTab) {
            WatchRecommendationView(navPath: $navPath).tag(0)
            WatchCategoryListView(selectedTab: $selectedTab, navPath: $navPath).tag(1)
            WatchRatedListView().tag(2)
            WatchWatchlistView().tag(3)
            WatchSettingsView().tag(4)
        }
        .tabViewStyle(.page)
    }
}

// 🟢 修改后的分类列表视图
struct WatchCategoryListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var selectedTab: Int
    @Binding var navPath: NavigationPath
    
    var body: some View {
        NavigationStack {
            List {
                // 1. 猜你喜欢 (重置分类)
                Button {
                    resetAndNavigate(to: nil)
                } label: {
                    HStack {
                        Image(systemName: "sparkles").foregroundColor(.yellow)
                        // 这里的 "猜你喜欢" 是字面量，SwiftUI 会自动翻译
                        Text("猜你喜欢")
                        Spacer()
                        if viewModel.selectedCategory == nil {
                            Image(systemName: "checkmark").font(.caption).foregroundColor(.blue)
                        }
                    }
                }
                
                // 2. 分类列表
                ForEach(viewModel.sortedCategories) { category in
                    Button {
                        resetAndNavigate(to: category)
                    } label: {
                        HStack {
                            // 🟢 关键修复：
                            // category.name 是变量，必须用 LocalizedStringKey 包裹才能触发本地化查找
                            Text(LocalizedStringKey(category.name))
                            
                            Spacer()
                            if viewModel.selectedCategory == category {
                                Image(systemName: "checkmark").font(.caption).foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("分类")
        }
    }
    
    private func resetAndNavigate(to category: CategoryItem?) {
        navPath = NavigationPath()
        withAnimation {
            selectedTab = 0
        }
        Task {
            await viewModel.changeCategory(to: category)
        }
    }
}
struct WatchRatedListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Query(sort: \SavedMovie.interactionDate, order: .reverse) var allRatedMovies: [SavedMovie]
    @State private var filterMode: Int = 0
    
    var filteredMovies: [SavedMovie] {
        filterMode == 1 ? allRatedMovies.filter { $0.isLiked } : allRatedMovies.filter { $0.isLiked || $0.isNeutral || $0.isDisliked }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 8) {
                    Button { withAnimation { filterMode = 0 } } label: {
                        Text("全部").font(.caption2).frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(filterMode == 0 ? Color.blue : Color.gray.opacity(0.3)).cornerRadius(8)
                    }.buttonStyle(.plain)
                    Button { withAnimation { filterMode = 1 } } label: {
                        Text("喜欢").font(.caption2).frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(filterMode == 1 ? Color.orange : Color.gray.opacity(0.3)).cornerRadius(8)
                    }.buttonStyle(.plain)
                }.padding(.horizontal).padding(.bottom, 5)
                
                if filteredMovies.isEmpty {
                    Spacer(); Text("暂无记录").foregroundColor(.secondary); Spacer()
                } else {
                    List {
                        ForEach(filteredMovies) { SavedMovie in
                            NavigationLink(destination: WatchMovieDetailView(movie: SavedMovie.toMovie)) {
                                HStack {
                                    if SavedMovie.isLiked { Image(systemName: "heart.fill").foregroundColor(.red).font(.caption2) }
                                    else if SavedMovie.isDisliked { Image(systemName: "hand.thumbsdown.fill").foregroundColor(.gray).font(.caption2) }
                                    else {
                                        // 🟢 修复：同步为 face.smiling (橙色)
                                        Image(systemName: "face.smiling").foregroundColor(.orange).font(.caption2)
                                    }
                                    Text(SavedMovie.title).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("已评价")
        }
    }
}

struct WatchWatchlistView: View {
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        NavigationStack {
            VStack {
                Label("待看清单", systemImage: "bookmark.fill")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                if viewModel.toWatchList.isEmpty {
                    Spacer()
                    VStack { Text("暂无待看").foregroundColor(.secondary) }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.toWatchList) { movie in
                            NavigationLink(destination: WatchMovieDetailView(movie: movie)) {
                                Text(movie.title).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }
}
