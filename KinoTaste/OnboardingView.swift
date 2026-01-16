//
//  OnboardingView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//

import SwiftUI
import UIKit // 🟢 引入 UIKit 以确保 UIImpactFeedbackGenerator 可用

// MARK: - 数据结构
struct SwipeTrigger: Equatable {
    let direction: Int
    let id = UUID()
}

// MARK: - 主视图
struct OnboardingView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var pendingMovie: Movie?
    
    // 🟢 1. 外部控制信号
    @State private var swipeTrigger: SwipeTrigger? = nil
    @State private var resetTrigger: Bool = false // 用于强制重置卡片位置
    
    // 复古黄 (与 MainView 保持一致)
    private let mutedYellow = Color(red: 0.92, green: 0.85, blue: 0.55)
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack {
                Text(LocalizedStringKey("定制你的口味"))
                    .retroFont(size: 24, bold: true)
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.vertical, 4)
                    .padding(.top, 20)
                
                Spacer()
                
                // 卡片堆叠区
                ZStack {
                    if viewModel.isLoading {
                        VStack(spacing: 15) {
                            ProgressView()
                            Text(LocalizedStringKey("正在为你精选..."))
                                .retroFont(size: 14)
                                .foregroundColor(.gray)
                        }
                    } else if let error = viewModel.errorMessage {
                        ErrorView(errorText: error) { viewModel.retry() }
                    } else if viewModel.onboardingMovies.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("准备就绪"))
                                .retroFont(size: 20, bold: true)
                        }
                    } else {
                        let movies = viewModel.onboardingMovies
                        let count = movies.count
                        let visibleItems = Array(movies.enumerated()).suffix(3)
                        
                        ForEach(visibleItems, id: \.element.id) { index, movie in
                            let order = count - 1 - index
                            
                            DraggableCardView(
                                movie: movie,
                                isTopCard: order == 0,
                                externalTrigger: swipeTrigger,
                                resetTrigger: resetTrigger,
                                onSwiped: { direction in handleSwipe(movie: movie, direction: direction) },
                                onPending: { viewModel.skipMovie(movie) }
                            )
                            .zIndex(Double(index))
                            .transition(.asymmetric(insertion: .opacity, removal: .identity))
                            .scaleEffect(order == 0 ? 1 : (order == 1 ? 0.95 : 0.9))
                            .offset(y: order == 0 ? 0 : (order == 1 ? 15 : 30))
                            .opacity(order > 1 ? 0 : 1)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: count)
                        }
                    }
                }
                .frame(height: 500)
                
                Spacer()
                
                // 底部区域
                ZStack {
                    if viewModel.seenCount >= 10 {
                        VStack(spacing: 16) {
                            // 🟢 修改：替换为复古胶囊按钮样式
                            Button(action: { viewModel.completeOnboardingEarly() }) {
                                HStack(spacing: 6) {
                                    Text(LocalizedStringKey("进入推荐页"))
                                        .retroFont(size: 18, bold: true)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(mutedYellow) // 文字颜色
                                .padding(.vertical, 14)
                                .padding(.horizontal, 32)
                                .background(Color.black) // 背景黑色
                                .clipShape(Capsule()) // 胶囊形状
                                .overlay(
                                    Capsule()
                                        .stroke(mutedYellow, lineWidth: 1.5) // 黄色描边
                                )
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }
                            
                            Text(LocalizedStringKey("滑得越多，推荐越懂你"))
                                .retroFont(size: 12)
                                .foregroundColor(.secondary)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        if !viewModel.onboardingMovies.isEmpty {
                            VStack(spacing: 15) {
                                SwipeLegendView { direction in
                                    withAnimation {
                                        swipeTrigger = SwipeTrigger(direction: direction)
                                    }
                                }
                                
                                Text(LocalizedStringKey("还需评价 \(10 - viewModel.seenCount) 部电影解锁推荐"))
                                    .retroFont(size: 12)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .padding(.bottom, 20)
                            .transition(.opacity)
                        }
                    }
                }
                .frame(height: 140)
                .padding(.bottom, 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.seenCount >= 10)
            }
            
            RetroFilmOverlay()
        }
        .sheet(item: $pendingMovie, onDismiss: {
            resetTrigger.toggle()
        }) { movie in
            RatingSheet(movie: movie, onSelect: { rating in
                pendingMovie = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    viewModel.submitRating(for: movie, rating: rating)
                }
            }, onCancel: {
                pendingMovie = nil
            })
        }
    }
    
    private func handleSwipe(movie: Movie, direction: Int) {
        swipeTrigger = nil
        if direction == 0 {
            pendingMovie = movie
        } else {
            viewModel.handleQuickSwipe(movie: movie, direction: direction)
        }
    }
}

// MARK: - 可拖拽卡片视图
struct DraggableCardView: View {
    let movie: Movie
    let isTopCard: Bool
    let externalTrigger: SwipeTrigger?
    let resetTrigger: Bool
    
    let onSwiped: (Int) -> Void
    let onPending: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var isDetailMode: Bool = false
    @State private var isDragging: Bool = false
    
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            MovieCardView(movie: movie, isOnboarding: true, isDetailMode: $isDetailMode)
                .frame(width: 320, height: 480)
                .overlay(alignment: .topTrailing) {
                    if isTopCard && !isDetailMode {
                        Button(action: {
                            impact.impactOccurred()
                            onPending()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14))
                                Text(LocalizedStringKey("待定"))
                                    .retroFont(size: 14, bold: true)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding([.top, .trailing], 16)
                    }
                }
            
            if isTopCard && !isDetailMode {
                OverlayIcon(name: "eye.fill", color: .blue, alignment: .topTrailing)
                    .opacity(offset.width < -50 ? 1 : 0)
                OverlayIcon(name: "bookmark.fill", color: Color(red: 0.92, green: 0.85, blue: 0.55), alignment: .topLeading)
                    .opacity(offset.width > 50 ? 1 : 0)
                OverlayIcon(name: "xmark", color: .gray, alignment: .bottom)
                    .opacity(offset.height < -50 ? 1 : 0)
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 15)))
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .onChange(of: externalTrigger) { newValue in
            guard isTopCard, !isDetailMode, let trigger = newValue else { return }
            let dir = trigger.direction
            var targetX: CGFloat = 0; var targetY: CGFloat = 0
            if dir == 0 { targetX = -600 }
            else if dir == 2 { targetX = 600 }
            else if dir == 1 { targetY = -800 }
            swipeOut(x: targetX, y: targetY, dir: dir)
        }
        .onChange(of: resetTrigger) { _ in
            if isTopCard {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    offset = .zero
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    guard isTopCard, !isDetailMode else { return }
                    if !isDragging { withAnimation(.easeInOut(duration: 0.1)) { isDragging = true } }
                    offset = gesture.translation
                }
                .onEnded { _ in
                    guard isTopCard, !isDetailMode else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { isDragging = false }
                    handleSwipeEnd()
                }
        )
    }
    
    private func handleSwipeEnd() {
        let threshold: CGFloat = 120
        if offset.width < -threshold { swipeOut(x: -600, y: offset.height, dir: 0) }
        else if offset.width > threshold { swipeOut(x: 600, y: offset.height, dir: 2) }
        else if offset.height < -threshold { swipeOut(x: offset.width, y: -800, dir: 1) }
        else { withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) { offset = .zero } }
    }
    
    private func swipeOut(x: CGFloat, y: CGFloat, dir: Int) {
        impact.impactOccurred()
        withAnimation(.easeIn(duration: 0.2)) {
            offset = CGSize(width: x, height: y)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSwiped(dir)
        }
    }
}

// MARK: - 辅助视图
struct OverlayIcon: View {
    let name: String; let color: Color; let alignment: Alignment
    var body: some View {
        ZStack { Color.clear; Image(systemName: name).font(.system(size: 80)).foregroundColor(color).shadow(radius: 2).padding(40) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .animation(.easeInOut(duration: 0.2), value: 1)
    }
}

struct RatingSheet: View {
    let movie: Movie
    let onSelect: (AppViewModel.RatingType) -> Void
    let onCancel: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 25) {
            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
            VStack(spacing: 8) {
                Text(LocalizedStringKey("评价这部电影"))
                    .retroFont(size: 18, bold: true)
                    .padding(.vertical, 4)
                Text(movie.title)
                    .retroFont(size: 14)
                    .padding(.vertical, 2)
                    .foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }
            HStack(spacing: 25) {
                OnboardingRatingBtn(icon: "heart.fill", text: "喜欢", color: .red) { onSelect(.like) }
                OnboardingRatingBtn(icon: "face.smiling.fill", text: "一般", color: .blue) { onSelect(.neutral) }
                OnboardingRatingBtn(icon: "hand.thumbsdown.fill", text: "不喜欢", color: .gray) { onSelect(.dislike) }
            }
            Button(action: { onCancel(); presentationMode.wrappedValue.dismiss() }) {
                Text(LocalizedStringKey("我点错了 (没看过)"))
                    .retroFont(size: 12)
                    .padding(.vertical, 4)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            Spacer()
        }
        .padding().presentationDetents([.height(300)]).presentationDragIndicator(.hidden)
    }
}

struct OnboardingRatingBtn: View {
    let icon: String; let text: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 30));
                Text(LocalizedStringKey(text))
                    .retroFont(size: 12, bold: true)
                    .padding(.vertical, 2)
            }
            .foregroundColor(color).frame(width: 85, height: 85).background(color.opacity(0.1)).cornerRadius(20)
        }
    }
}
