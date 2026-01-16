//
//  MainView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SDWebImageSwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showSearch = false
    @State private var showCategorySheet = false
    @State private var showInspiration = false
    
    // 🟢 1. 引入 SizeClass 以区分 iPad/iPhone 及分屏状态
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    // 统一的低饱和复古黄
    private let mutedYellow = Color(red: 0.92, green: 0.85, blue: 0.55)
    
    // 🟢 2. 定义网格列数配置
    private var columns: [GridItem] {
        if sizeClass == .regular {
            // iPad (或大屏 iPhone 横屏): 双列，列间距 20
            return [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ]
        } else {
            // iPhone (或 iPad 分屏窄窗口): 单列
            return [GridItem(.flexible())]
        }
    }
    
    var body: some View {
        TabView {
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        
                        ScrollViewReader { scrollProxy in
                            
                            // MARK: - 1. 顶部 Header
                            VStack(spacing: 15) {
                                HStack(alignment: .center) {
                                    // 本地化："发现"
                                    Text(LocalizedStringKey("发现"))
                                        .retroFont(size: 34, bold: true)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                    
                                    Spacer()
                                    
                                    // 灵感按钮
                                    if !viewModel.isLoading {
                                        Button(action: { showInspiration = true }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "bolt.fill")
                                                    .font(.system(size: 14))
                                                
                                                // 本地化 + 强制单行
                                                Text(LocalizedStringKey("灵感"))
                                                    .retroFont(size: 16, bold: true)
                                                    .lineLimit(1)
                                                    .fixedSize()
                                            }
                                            .foregroundColor(mutedYellow)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.black)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(mutedYellow, lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                        .padding(.trailing, 8)
                                    }
                                    
                                    // 刷新按钮
                                    Button(action: {
                                        Task {
                                            let previousCount = viewModel.recommendedMovies.count
                                            await viewModel.refreshRecommendations(reset: false)
                                            
                                            if viewModel.recommendedMovies.count > previousCount {
                                                let firstNewMovie = viewModel.recommendedMovies[previousCount]
                                                try? await Task.sleep(nanoseconds: 100_000_000)
                                                withAnimation(.spring()) {
                                                    scrollProxy.scrollTo(firstNewMovie.id, anchor: .top)
                                                }
                                            }
                                        }
                                    }) {
                                        Group {
                                            if viewModel.isLoading {
                                                ProgressView().tint(.primary)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .frame(width: 20, height: 20)
                                        .padding(10)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    }
                                    .disabled(viewModel.isLoading)
                                    .padding(.trailing, 8)
                                    
                                    // 搜索按钮 (已改回直接点击进入)
                                    Button(action: {
                                        viewModel.clearSearch()
                                        viewModel.searchMode = .normal
                                        showSearch = true
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .padding(10)
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
                                            .clipShape(Circle())
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                                
                                // 双按钮导航
                                HStack(spacing: 12) {
                                    SelectionButton(
                                        title: "✨ 猜你喜欢",
                                        isSelected: viewModel.selectedCategory == nil
                                    ) {
                                        Task {
                                            await viewModel.changeCategory(to: nil)
                                            withAnimation { scrollProxy.scrollTo("TOP_ANCHOR", anchor: .top) }
                                        }
                                    }
                                    
                                    SelectionButton(
                                        title: viewModel.selectedCategory?.name ?? "🎞️ 分类胶卷",
                                        isSelected: viewModel.selectedCategory != nil,
                                        isExpandable: true
                                    ) {
                                        showCategorySheet = true
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                            }
                            .background(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 5, y: 5)
                            .zIndex(1)
                            
                            // MARK: - 2. 电影列表内容
                            if viewModel.isLoading && viewModel.recommendedMovies.isEmpty {
                                Spacer()
                                VStack(spacing: 15) {
                                    ProgressView().scaleEffect(1.2)
                                    Text(LocalizedStringKey("正在冲洗胶片..."))
                                        .retroFont(size: 12)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            } else if let error = viewModel.errorMessage {
                                Spacer()
                                ErrorView(errorText: error) { viewModel.retry() }
                                Spacer()
                            } else {
                                ScrollView {
                                    Color.clear.frame(height: 1).id("TOP_ANCHOR")
                                    
                                    // 🟢 3. 使用 LazyVGrid 替代 LazyVStack
                                    LazyVGrid(columns: columns, spacing: 24) {
                                        ForEach(Array(viewModel.recommendedMovies.enumerated()), id: \.element.id) { index, movie in
                                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                                MovieCardView(movie: movie, isDetailMode: .constant(false))
                                                    // 🟢 注意：这里移除了 .padding(.horizontal)
                                                    // 将内边距移动到了 Grid 容器上，避免双列时中间空隙过大
                                                    .contextMenu {
                                                        Button {
                                                            viewModel.toggleWatchlistContext(movie)
                                                        } label: {
                                                            let isAdded = viewModel.isMovieToWatch(movie.id)
                                                            Label(isAdded ? LocalizedStringKey("移出待看") : LocalizedStringKey("加入待看"), systemImage: isAdded ? "bookmark.fill" : "bookmark")
                                                        }
                                                        Divider()
                                                        Button { viewModel.rateMovie(movie: movie, type: .like) } label: { Label(LocalizedStringKey("喜欢"), systemImage: "heart") }
                                                        Button { viewModel.rateMovie(movie: movie, type: .neutral) } label: { Label(LocalizedStringKey("一般"), systemImage: "face.smiling") }
                                                        Button { viewModel.rateMovie(movie: movie, type: .dislike) } label: { Label(LocalizedStringKey("不喜欢"), systemImage: "hand.thumbsdown") }
                                                        Button(role: .destructive) { viewModel.rateMovie(movie: movie, type: .notInterested) } label: { Label(LocalizedStringKey("不想看"), systemImage: "eye.slash") }
                                                        
                                                        Button {
                                                            viewModel.skipMovie(movie)
                                                        } label: {
                                                            Label(LocalizedStringKey("待定"), systemImage: "questionmark.circle")
                                                        }
                                                    } preview: {
                                                        MovieContextMenuPreview(movie: movie)
                                                    }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .id(movie.id)
                                            .zIndex(Double(viewModel.recommendedMovies.count - index))
                                            .transition(
                                                .asymmetric(
                                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                                    removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.8))
                                                )
                                            )
                                        }
                                    }
                                    .padding(.horizontal) // 🟢 4. 统一给 Grid 添加水平内边距
                                    .padding(.top, 20)
                                    
                                    // 🟢 5. "加载更多"按钮移出 Grid (确保它始终占据整行)
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            
                                            Task {
                                                let previousCount = viewModel.recommendedMovies.count
                                                await viewModel.refreshRecommendations(reset: false)
                                                
                                                if viewModel.recommendedMovies.count > previousCount {
                                                    let firstNewMovie = viewModel.recommendedMovies[previousCount]
                                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                                    withAnimation(.spring()) {
                                                        scrollProxy.scrollTo(firstNewMovie.id, anchor: .top)
                                                    }
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                if viewModel.isLoading {
                                                    ProgressView().scaleEffect(0.7)
                                                    Text(LocalizedStringKey("正在加载..."))
                                                        .retroFont(size: 14, bold: true)
                                                } else {
                                                    Image(systemName: "arrow.clockwise")
                                                        .font(.system(size: 14, weight: .bold))
                                                    Text(LocalizedStringKey("加载更多"))
                                                        .retroFont(size: 14, bold: true)
                                                }
                                            }
                                            .foregroundColor(.primary.opacity(0.7))
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 24)
                                            .background(
                                                Capsule()
                                                    .fill(Color(UIColor.systemBackground))
                                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(mutedYellow, lineWidth: 1.5)
                                            )
                                        }
                                        .buttonStyle(MainViewScaleButtonStyle())
                                        .disabled(viewModel.isLoading)
                                        Spacer()
                                    }
                                    .padding(.vertical, 30)
                                    
                                    Color.clear.frame(height: 1).id("BOTTOM_ANCHOR")
                                }
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.recommendedMovies)
                            }
                        }
                    }
                    .navigationBarHidden(true)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label(LocalizedStringKey("推荐"), systemImage: "film.stack") }
            .sheet(isPresented: $showSearch) { SearchView(viewModel: viewModel) }
            .sheet(isPresented: $showCategorySheet) {
                FilmRollView(viewModel: viewModel, isPresented: $showCategorySheet)
            }
            .fullScreenCover(isPresented: $showInspiration) {
                InspirationView(viewModel: viewModel)
            }
            ProfileView(viewModel: viewModel)
                .tabItem { Label(LocalizedStringKey("我的"), systemImage: "person.crop.circle") }
        }
    }
}

// 辅助组件定义
private struct MainViewScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct FilmRollView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    private let filmColor = Color(red: 0.12, green: 0.12, blue: 0.12)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Text(LocalizedStringKey("胶卷盒"))
                        .retroFont(size: 20, bold: true)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        .foregroundColor(.white).padding(.leading)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    .padding(.trailing)
                }
                .background(filmColor)
                
                ScrollView {
                    VStack(spacing: 0) {
                        FilmLeaderShape().fill(filmColor).frame(height: 60).frame(maxWidth: .infinity).padding(.horizontal, 20)
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.sortedCategories.enumerated()), id: \.element.id) { index, category in
                                Button(action: {
                                    Task { await viewModel.changeCategory(to: category) }
                                    isPresented = false
                                }) {
                                    FilmFrameRow(title: category.name, index: index + 1, isSelected: viewModel.selectedCategory == category)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }.background(filmColor)
                        Rectangle().fill(filmColor).frame(height: 50).overlay(
                            Text("END OF ROLL")
                                .retroFont(size: 10)
                                .foregroundColor(.gray.opacity(0.5))
                        )
                    }.padding(.vertical, 20)
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct FilmFrameRow: View {
    let title: String; let index: Int; let isSelected: Bool
    var body: some View {
        HStack(spacing: 0) {
            SprocketColumn(side: .left, index: index).frame(width: 40)
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(isSelected ? Color.white : Color.black).padding(.vertical, 8)
                if isSelected {
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey(title))
                            .retroFont(size: 20, bold: true)
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("SELECTED")
                            .retroFont(size: 8, bold: true)
                            .tracking(2).foregroundColor(.blue)
                    }
                } else {
                    Text(LocalizedStringKey(title))
                        .retroFont(size: 18, bold: true)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 120).padding(.horizontal, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2).padding(.vertical, 8))
            SprocketColumn(side: .right, index: index).frame(width: 40)
        }
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1), alignment: .bottom)
    }
}

struct SprocketColumn: View {
    enum Side { case left, right }
    let side: Side; let index: Int
    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.12, blue: 0.12)
            VStack(spacing: 12) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.05)).frame(width: 12, height: 18)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
            }
            VStack {
                if side == .left {
                    Spacer(); Text("\(index)")
                        .retroFont(size: 10, bold: true)
                        .foregroundColor(.yellow.opacity(0.6)).rotationEffect(.degrees(-90)).offset(x: -12); Spacer()
                } else {
                    Spacer(); Text("KINO 400")
                        .retroFont(size: 8, bold: true)
                        .foregroundColor(.yellow.opacity(0.4)).rotationEffect(.degrees(90)).offset(x: 12); Spacer()
                }
            }
        }
    }
}

struct FilmLeaderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 20))
        path.addLine(to: CGPoint(x: rect.midX + 20, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 20))
        path.closeSubpath(); return path
    }
}

struct SelectionButton: View {
    let title: String; let isSelected: Bool; var isExpandable: Bool = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(LocalizedStringKey(title))
                    .retroFont(size: 16, bold: true)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isExpandable { Spacer(); Image(systemName: "chevron.down").font(.caption.bold()).opacity(0.6) }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.vertical, 14).padding(.horizontal, 16).frame(maxWidth: .infinity)
            .background(isSelected ? Color.black : Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: isSelected ? Color.black.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct MovieContextMenuPreview: View {
    let movie: Movie
    
    var body: some View {
        WebImage(url: movie.posterURL)
            .resizable()
            .indicator(.activity)
            .aspectRatio(contentMode: .fill)
            .frame(width: 300, height: 450)
            .clipped()
            .background(Color.black)
    }
}
