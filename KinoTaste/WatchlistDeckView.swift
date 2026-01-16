//
//  WatchlistDeckView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/12.
//

import SwiftUI
import SDWebImageSwiftUI
import SwiftData

struct WatchlistDeckView: View {
    // 原始数据
    let movies: [SavedMovie]
    
    @Environment(\.presentationMode) var presentationMode
    
    // 本地牌堆状态
    @State private var deck: [SavedMovie] = []
    
    // 🟢 动画状态控制
    @State private var isShuffling: Bool = false // 骰子旋转状态
    @State private var isExploded: Bool = false  // 卡片是否处于“炸开”状态
    
    // 🟢 杂乱堆叠参数 (每张卡片固定的随机偏移，制造“乱”的感觉)
    @State private var messyOffsets: [CGSize] = []
    @State private var messyRotations: [Double] = []
    
    // 🟢 洗牌时的爆炸参数 (洗牌时卡片飞去哪里)
    @State private var explosionOffsets: [CGSize] = []
    @State private var explosionRotations: [Double] = []
    
    // 拖拽偏移量 (仅针对最顶层卡片)
    @State private var topCardOffset: CGSize = .zero
    
    @State private var showSuggestion: Bool = false
    @State private var selectedMovie: SavedMovie? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                // 0. 隐形导航链接 (负责跳转逻辑)
                NavigationLink(
                    destination: Group {
                        if let movie = selectedMovie {
                            // 传入本地化后的 Movie 对象
                            // autoDismiss: true 确保操作后立即返回
                            MovieDetailView(movie: movie.toMovie, autoDismiss: true)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: Binding(
                        get: { selectedMovie != nil },
                        set: { if !$0 { selectedMovie = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
                
                // 1. 全屏背景：磨砂质感低饱和色 (模拟桌面)
                // 🟢 确保铺满屏幕，无视安全区域
                TabletopBackground()
                    .ignoresSafeArea()
                
                // 2. 内容区域
                VStack(spacing: 0) {
                    // 2.1 顶部栏
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            // 🟢 本地化
                            Text(LocalizedStringKey("待看清单"))
                                .retroFont(size: 18, bold: true)
                            Text("(\(deck.count))")
                                .retroFont(size: 18, bold: true)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        
                        Spacer()
                        
                        // 洗牌按钮
                        Button(action: shuffleDeck) {
                            Image(systemName: "dice.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                                // 骰子旋转时间加长，配合爆炸动画
                                .rotationEffect(.degrees(isShuffling ? 720 : 0))
                                .animation(.easeInOut(duration: 1.2), value: isShuffling)
                        }
                        .disabled(isShuffling || deck.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // 2.2 推荐提示语
                    if showSuggestion {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").foregroundColor(.yellow)
                            // 🟢 本地化
                            Text(LocalizedStringKey("不如今天看这部？"))
                                .retroFont(size: 16, bold: true)
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.3)) // 调淡背景，融合磨砂底色
                        .cornerRadius(20)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 60)
                    } else {
                        Spacer().frame(height: 50)
                    }
                    
                    // 2.3 卡片堆叠区
                    if deck.isEmpty {
                        EmptyStateView()
                    } else {
                        ZStack {
                            // 渲染顺序：index 0 在最下面，last 在最上面
                            ForEach(Array(deck.enumerated()), id: \.element.id) { index, movie in
                                let isTop = (index == deck.count - 1)
                                
                                // --- 位置计算逻辑 ---
                                
                                // 1. 基础杂乱偏移
                                let baseOffsetX = index < messyOffsets.count ? messyOffsets[index].width : 0
                                let baseOffsetY = index < messyOffsets.count ? messyOffsets[index].height : 0
                                let baseRotation = index < messyRotations.count ? messyRotations[index] : 0
                                
                                // 2. 爆炸偏移 (洗牌时生效)
                                let explodeOffsetX = index < explosionOffsets.count ? explosionOffsets[index].width : 0
                                let explodeOffsetY = index < explosionOffsets.count ? explosionOffsets[index].height : 0
                                let explodeRotation = index < explosionRotations.count ? explosionRotations[index] : 0
                                
                                // 3. 拖拽偏移 (仅顶层)
                                let dragOffsetX = isTop ? topCardOffset.width : 0
                                let dragOffsetY = isTop ? topCardOffset.height : 0
                                
                                // 4. 最终合成
                                // 如果正在爆炸，使用爆炸参数；否则使用杂乱参数 + 拖拽
                                let finalX = isExploded ? explodeOffsetX : (baseOffsetX + dragOffsetX)
                                let finalY = isExploded ? explodeOffsetY : (baseOffsetY + dragOffsetY)
                                let finalRot = isExploded ? explodeRotation : (baseRotation + (isTop ? Double(topCardOffset.width / 15) : 0))
                                
                                // 5. 缩放
                                // 顶层 1.0，底层稍微缩小，但在爆炸时为了视觉效果全部恢复 1.0
                                let scale = isExploded ? 1.0 : (isTop ? 1.0 : 0.95)
                                
                                LiveMovieCard(savedMovie: movie)
                                    .scaleEffect(scale)
                                    .rotationEffect(.degrees(finalRot))
                                    .offset(x: finalX, y: finalY)
                                    // 加重阴影，增加“桌面”上的立体感
                                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
                                    // 手势
                                    .gesture(
                                        isTop && !isShuffling ? DragGesture()
                                            .onChanged { value in topCardOffset = value.translation }
                                            .onEnded { value in handleDragEnd(value, movie: movie) } : nil
                                    )
                                    .onTapGesture {
                                        if isTop && !isShuffling { selectedMovie = movie }
                                    }
                                    .zIndex(Double(index))
                                    // 🟢 关键：禁用默认插入动画，完全靠 offset 控制位置，防止循环时闪烁
                                    .transition(.identity)
                            }
                        }
                        .frame(height: 450)
                    }
                    
                    Spacer()
                    
                    // 2.4 底部标题
                    if let topMovie = deck.last, !isExploded {
                        LiveMovieTitle(savedMovie: topMovie)
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                            .id(topMovie.id)
                            .transition(.opacity)
                    } else {
                        Spacer().frame(height: 80)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            self.deck = movies
            generateMessyState()
        }
        .onChange(of: movies) { newVal in
            withAnimation(.spring()) { self.deck = newVal }
            if newVal.isEmpty { showSuggestion = false }
            generateMessyState()
        }
    }
    
    // MARK: - Logic
    
    // 生成“杂乱”状态：卡片平时摆放的样子
    private func generateMessyState() {
        // 范围增大，看起来更乱
        messyOffsets = (0..<100).map { _ in
            CGSize(
                width: CGFloat.random(in: -25...25),
                height: CGFloat.random(in: -25...25)
            )
        }
        messyRotations = (0..<100).map { _ in
            Double.random(in: -12...12)
        }
    }
    
    // 生成“爆炸”状态：洗牌时卡片飞出的位置
    private func generateExplosionState() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        explosionOffsets = (0..<100).map { _ in
            CGSize(
                width: CGFloat.random(in: -screenWidth/1.5 ... screenWidth/1.5),
                height: CGFloat.random(in: -screenHeight/3 ... screenHeight/3)
            )
        }
        explosionRotations = (0..<100).map { _ in
            Double.random(in: -45...45) // 炸开时旋转更剧烈
        }
    }
    
    private func shuffleDeck() {
        guard !deck.isEmpty else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // 0. 准备爆炸数据
        generateExplosionState()
        
        // 1. 触发爆炸动画 (0.4s)
        withAnimation(.easeOut(duration: 0.4)) {
            isShuffling = true
            isExploded = true
            showSuggestion = false
        }
        
        // 2. 在爆炸状态掩护下，悄悄打乱数据 (0.5s 时)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var newDeck = deck
            newDeck.shuffle()
            
            // 重要：打乱数据的同时，也要重新生成杂乱状态，这样回归时位置是新的
            deck = newDeck
            generateMessyState()
        }
        
        // 3. 收回卡片 (吸铁石效果) (0.8s 开始收，持续 0.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                isExploded = false
            }
        }
        
        // 4. 彻底结束
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            isShuffling = false
            showSuggestion = true
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value, movie: SavedMovie) {
        let threshold: CGFloat = 100
        let translation = value.translation.width
        let screenWidth = UIScreen.main.bounds.width
        
        if abs(translation) > threshold {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // 1. 飞出屏幕
            withAnimation(.easeIn(duration: 0.2)) {
                topCardOffset.width = translation > 0 ? screenWidth * 1.2 : -screenWidth * 1.2
            }
            
            // 2. 悄悄换到底部
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                topCardOffset = .zero
                
                if let idx = deck.firstIndex(where: { $0.id == movie.id }) {
                    let item = deck.remove(at: idx)
                    deck.insert(item, at: 0)
                    
                    // 为了自然，插到底部时给它一个新的随机位置
                    if !messyOffsets.isEmpty {
                        messyOffsets[0] = CGSize(width: CGFloat.random(in: -25...25), height: CGFloat.random(in: -25...25))
                        messyRotations[0] = Double.random(in: -12...12)
                    }
                }
            }
        } else {
            // 回弹
            withAnimation(.spring()) { topCardOffset = .zero }
        }
    }
}

// MARK: - 桌面背景 (模拟磨砂质感)
struct TabletopBackground: View {
    var body: some View {
        ZStack {
            // 1. 底色：低饱和度深岩石灰/深蓝灰
            Color(red: 0.18, green: 0.18, blue: 0.20)
            
            // 2. 磨砂纹理层
            MatteTexture()
                .opacity(0.15) // 控制纹理明显程度
                .blendMode(.overlay)
        }
    }
}

// 绘制细腻的随机噪点
struct MatteTexture: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                // 增加点的密度来模拟磨砂
                let count = Int(width * height * 0.05)
                
                for _ in 0..<count {
                    let x = Double.random(in: 0...width)
                    let y = Double.random(in: 0...height)
                    let s = Double.random(in: 0.5...1.5)
                    let rect = CGRect(x: x, y: y, width: s, height: s)
                    // 使用白色或淡灰色点
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 其他辅助组件

struct LiveMovieCard: View {
    let savedMovie: SavedMovie
    @State private var posterURL: URL?
    
    var body: some View {
        WebImage(url: posterURL ?? savedMovie.toMovie.posterURL)
            .resizable()
            .indicator(.activity)
            .aspectRatio(contentMode: .fill)
            .frame(width: 300, height: 450)
            .cornerRadius(20)
            .clipped()
            // 加粗白边，更有照片卡片的感觉
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.8), lineWidth: 3)
            )
            .background(Color.black)
            .cornerRadius(20)
            .task {
                if let fresh = try? await TMDBService.shared.fetchMovieDetails(movieId: savedMovie.id) {
                    self.posterURL = fresh.posterURL
                }
            }
    }
}

struct LiveMovieTitle: View {
    let savedMovie: SavedMovie
    @State private var title: String
    
    init(savedMovie: SavedMovie) {
        self.savedMovie = savedMovie
        _title = State(initialValue: savedMovie.title)
    }
    
    var body: some View {
        Text(title)
            .retroFont(size: 22, bold: true)
            .padding(.top, 4)
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .task {
                if let fresh = try? await TMDBService.shared.fetchMovieDetails(movieId: savedMovie.id) {
                    self.title = fresh.title
                }
            }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "popcorn")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            // 🟢 本地化
            Text(LocalizedStringKey("待看清单是空的"))
                .retroFont(size: 20, bold: true)
                .foregroundColor(.white.opacity(0.8))
            
            // 🟢 本地化
            Text(LocalizedStringKey("去推荐页加几部电影吧"))
                .retroFont(size: 14)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
