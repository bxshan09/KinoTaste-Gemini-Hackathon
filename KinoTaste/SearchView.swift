//
//  SearchView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SDWebImageSwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var query: String = ""
    @FocusState private var isFocused: Bool
    
    // 复古黄
    private let mutedYellow = Color(red: 0.92, green: 0.85, blue: 0.55)
    
    var body: some View {
        NavigationView {
            ZStack {
                // 🟢 1. 动态背景：AI 模式下显示淡紫色氛围
                if viewModel.searchMode == .ai {
                    Color.purple.opacity(0.05).ignoresSafeArea()
                } else {
                    Color(UIColor.systemBackground).ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    
                    // 🟢 2. 顶部模式切换栏 (复活)
                    HStack(spacing: 20) {
                        SearchModeButton(title: "常规搜索", isSelected: viewModel.searchMode == .normal) {
                            withAnimation { viewModel.searchMode = .normal }
                        }
                        
                        SearchModeButton(title: "记忆碎片", icon: "sparkles", isSelected: viewModel.searchMode == .ai) {
                            withAnimation { viewModel.searchMode = .ai }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                    
                    // MARK: - 搜索输入区
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            ZStack(alignment: .leading) {
                                if query.isEmpty {
                                    // 🟢 3. 动态占位符
                                    if viewModel.searchMode == .ai {
                                        Text(LocalizedStringKey("描述剧情、场景或模糊的记忆..."))
                                            .retroFont(size: 14)
                                            .foregroundColor(.purple.opacity(0.6))
                                    } else {
                                        Text(LocalizedStringKey("搜索电影 / 影人"))
                                            .retroFont(size: 14)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                TextField("", text: $query)
                                    .submitLabel(.search)
                                    .focused($isFocused)
                                    .retroFont(size: 16)
                                    .onSubmit { triggerSearch() }
                            }
                            
                            if !query.isEmpty {
                                Button(action: { query = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6)) // 输入框背景保持灰色，突出层次
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 10) // 调整间距
                    }
                    
                    // MARK: - 内容展示
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 20) {
                            ProgressView()
                            if viewModel.searchMode == .ai {
                                Text(LocalizedStringKey("正在重组记忆碎片..."))
                                    .retroFont(size: 14)
                                    .foregroundColor(.purple)
                            }
                        }
                        .transition(.opacity)
                        Spacer()
                        
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.gray)
                            Text(LocalizedStringKey(error))
                                .retroFont(size: 14)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Button(action: { triggerSearch() }) {
                                Text(LocalizedStringKey("重试")).retroFont(size: 14, bold: true)
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                        
                    } else if viewModel.currentSearchResults.isEmpty && viewModel.searchPeopleResults.isEmpty && !query.isEmpty && !viewModel.isSearching {
                        Spacer()
                        Text(LocalizedStringKey("未找到相关内容"))
                            .retroFont(size: 16)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                    } else {
                        List {
                            // 1. 影人结果 (仅常规模式显示)
                            if viewModel.searchMode == .normal && !viewModel.searchPeopleResults.isEmpty {
                                Section(header: Text(LocalizedStringKey("影人")).retroFont(size: 14, bold: true)) {
                                    ForEach(viewModel.searchPeopleResults) { person in
                                        NavigationLink(destination: DirectorMoviesView(director: person)) {
                                            Text(person.name).retroFont(size: 16)
                                        }
                                    }
                                }
                            }
                            
                            // 2. 电影结果
                            if !viewModel.currentSearchResults.isEmpty {
                                Section(header: Text(LocalizedStringKey("电影")).retroFont(size: 14, bold: true)) {
                                    ForEach(viewModel.currentSearchResults) { movie in
                                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                                            // 🟢 4. 传入 isAI 参数，控制显示样式
                                            MovieRowView(movie: movie, isAI: viewModel.searchMode == .ai)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .id(UUID()) // 强制刷新列表
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                isFocused = true
                // 注意：这里不要再强制 .normal，保留用户上次的选择或让 MainView 控制
            }
            .onChange(of: query) { newValue in
                if newValue.isEmpty { viewModel.clearSearch() }
            }
        }
    }
    
    private func triggerSearch() {
        isFocused = false
        Task {
            // 🟢 5. 恢复搜索逻辑分支
            if viewModel.searchMode == .ai {
                await viewModel.performAISearch(query: query)
            } else {
                await viewModel.performNormalSearch(query: query)
            }
        }
    }
}

// 🟢 6. 新增：顶部切换按钮组件
struct SearchModeButton: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(LocalizedStringKey(title))
            }
            .retroFont(size: 15, bold: isSelected)
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
            )
        }
        .buttonStyle(SearchScaleButtonStyle())
    }
}

// 🟢 7. 增强版 RowView (支持显示 AI 推荐理由)
struct MovieRowView: View {
    let movie: Movie
    var isAI: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WebImage(url: movie.posterURL)
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 75)
                .cornerRadius(4)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .retroFont(size: 16, bold: true)
                    .lineLimit(2)
                
                // 🟢 如果是 AI 模式，显示紫色高亮的推荐理由
                if isAI, let reason = movie.recommendationReason {
                    Text(reason)
                        .retroFont(size: 12)
                        .foregroundColor(.purple.opacity(0.8))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(movie.year)
                        .retroFont(size: 12)
                        .foregroundColor(.secondary)
                    Text(movie.overview)
                        .retroFont(size: 10)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
