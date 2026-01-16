// ==========================================
// FILE PATH: ./KinoTaste Watch/WatchOnboardingView.swift
// ==========================================

import SwiftUI
import SDWebImageSwiftUI
import WatchKit

struct WatchOnboardingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var interactionCount: Int = 0
    private let minTarget = 10
    
    // 控制简介显示的状态
    @State private var showOverview: Bool = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    // 主布局：垂直排列
                    VStack(spacing: 0) {
                        // 1. 顶部进度 (压缩到极致)
                        if interactionCount >= minTarget {
                            // 留一点点空隙给悬浮按钮
                            Spacer().frame(height: 20)
                        } else {
                            Text("\(interactionCount) / \(minTarget)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(height: 16)
                                .padding(.top, 2)
                        }
                        
                        // 2. 卡片区域 (自动撑满剩余空间)
                        if let movie = viewModel.onboardingMovies.first {
                            DraggableWatchCard(
                                movie: movie,
                                showOverview: $showOverview,
                                onRate: { type in handleRate(movie, type: type) }
                            )
                            .id(movie.id)
                            .zIndex(1)
                            // 🟢 动态布局：让卡片纵向伸展填满空间，但保持左右不溢出
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 4)
                            
                            // 3. 底部按钮 (固定高度，不挤占海报)
                            HStack(spacing: 0) {
                                OnboardingIconButton(icon: "bookmark", color: .blue) { handleRate(movie, type: .addToWatch) }
                                Spacer()
                                OnboardingIconButton(icon: "heart.fill", color: .red) { handleRate(movie, type: .like) }
                                Spacer()
                                OnboardingIconButton(icon: "face.smiling", color: .orange) { handleRate(movie, type: .neutral) }
                                Spacer()
                                OnboardingIconButton(icon: "hand.thumbsdown.fill", color: .gray) { handleRate(movie, type: .dislike) }
                                Spacer()
                                OnboardingIconButton(icon: "eye.slash.fill", color: .purple) { handleRate(movie, type: .notInterested) }
                            }
                            .padding(.horizontal, 2)
                            .padding(.bottom, 2)
                            .zIndex(2)
                            
                        } else {
                            // 加载状态
                            VStack(spacing: 10) {
                                ProgressView()
                                Text("准备片单...").font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    
                    // 悬浮按钮 (进入首页)
                    if interactionCount >= minTarget {
                        VStack {
                            Button {
                                WKInterfaceDevice.current().play(.success)
                                withAnimation(.easeInOut) {
                                    viewModel.completeOnboardingEarly()
                                }
                            } label: {
                                Text("进入首页")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.horizontal, 12)
                            .padding(.top, 0)
                        }
                        .zIndex(999)
                    }
                }
            }
            .navigationTitle("定制口味")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func handleRate(_ movie: Movie, type: AppViewModel.RatingType) {
        WKInterfaceDevice.current().play(.click)
        withAnimation {
            showOverview = false
            viewModel.rateMovie(movie: movie, type: type)
            if let index = viewModel.onboardingMovies.firstIndex(where: { $0.id == movie.id }) {
                viewModel.onboardingMovies.remove(at: index)
            }
            interactionCount += 1
        }
    }
}

// 可拖拽卡片 (适配自动高度 + 手势修复)
struct DraggableWatchCard: View {
    let movie: Movie
    @Binding var showOverview: Bool
    let onRate: (AppViewModel.RatingType) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showOverview {
                    // --- 背面：剧情简介 ---
                    ZStack {
                        // 背景层
                        Color.black.opacity(0.95).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // 顶部固定栏 (标题 + 关闭按钮)
                            HStack {
                                Image(systemName: "info.circle.fill").font(.caption2)
                                Text("剧情简介").font(.system(size: 10, weight: .bold))
                                Spacer()
                                // 显式关闭按钮
                                Button {
                                    withAnimation(.spring()) { showOverview = false }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.black)
                            
                            // 🟢 ScrollView 区域
                            ScrollView {
                                Text(movie.overview.isEmpty ? "暂无简介" : movie.overview)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(1)
                                    .padding(.horizontal, 6)
                                    .padding(.bottom, 6)
                                    // 🟢 关键技巧：给文本加个全宽 frame，确保即使点击空白处也能响应
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    // 🟢 修复：添加点击手势，允许轻点退回
                    // 注意：这不会阻止 ScrollView 的滑动，因为 ScrollView 的 Drag 优先级更高
                    .onTapGesture {
                        withAnimation(.spring()) { showOverview = false }
                    }
                    
                } else {
                    // --- 正面：海报 ---
                    WatchMovieCard(movie: movie)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack(spacing: 3) {
                                    Image(systemName: "hand.tap.fill")
                                    Text("简介")
                                }
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.bottom, 4)
                                .shadow(color: .black, radius: 2)
                            }
                        )
                        .overlay(
                            ZStack {
                                if offset.width < -30 { Image(systemName: "eye.slash.fill").font(.title).foregroundColor(.purple) }
                                else if offset.width > 30 { Image(systemName: "heart.fill").font(.title).foregroundColor(.red) }
                            }
                        )
                        // 长按翻转
                        .onLongPressGesture(minimumDuration: 0.3) {
                            WKInterfaceDevice.current().play(.click)
                            withAnimation(.spring()) { showOverview = true }
                        }
                        // 拖拽评分 (只在正面生效)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    withAnimation(.interactiveSpring()) {
                                        offset = gesture.translation
                                        isDragging = true
                                    }
                                }
                                .onEnded { _ in handleSwipeEnd() }
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(showOverview ? .zero : offset)
            .rotationEffect(.degrees(showOverview ? 0 : Double(offset.width / 20)))
            .scaleEffect(isDragging ? 1.05 : 1.0)
        }
    }
    
    private func handleSwipeEnd() {
        let threshold: CGFloat = 50
        if offset.width < -threshold { swipeAndRate(.notInterested, x: -150) }
        else if offset.width > threshold { swipeAndRate(.like, x: 150) }
        else { withAnimation(.spring()) { offset = .zero; isDragging = false } }
    }
    
    private func swipeAndRate(_ type: AppViewModel.RatingType, x: CGFloat) {
        WKInterfaceDevice.current().play(.click)
        withAnimation(.easeIn(duration: 0.2)) { offset = CGSize(width: x, height: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onRate(type); offset = .zero; isDragging = false }
    }
}

struct OnboardingIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .clipShape(Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
