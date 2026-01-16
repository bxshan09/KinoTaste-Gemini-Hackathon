//
//  InspirationView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/12.
//

import SwiftUI
import SDWebImageSwiftUI

struct InspirationView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var pendingMovie: Movie?
    @State private var swipeTrigger: SwipeTrigger? = nil
    @State private var resetTrigger: Bool = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack {
                // 1. 顶部栏
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("灵感模式")
                                .retroFont(size: 24, bold: true) // ✅
                        }
                    }
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // 2. 卡片堆叠区
                ZStack {
                    if viewModel.isLoading && viewModel.inspirationMovies.isEmpty {
                        VStack(spacing: 15) {
                            ProgressView()
                            Text("正在寻找灵感...")
                                .retroFont(size: 14) // ✅
                                .foregroundColor(.secondary)
                        }
                    } else if viewModel.inspirationMovies.isEmpty {
                        VStack(spacing: 15) {
                            Image(systemName: "film.stack").font(.largeTitle).foregroundColor(.gray)
                            Text("片库空空如也")
                                .retroFont(size: 18, bold: true) // ✅
                                .foregroundColor(.secondary)
                            Button(action: { Task { await viewModel.loadInspirationData() } }) {
                                Text("刷新试试")
                                    .retroFont(size: 14, bold: true) // ✅
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        let movies = viewModel.inspirationMovies
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
                
                // 3. 底部按钮
                if !viewModel.inspirationMovies.isEmpty {
                    SwipeLegendView { direction in
                        withAnimation {
                            swipeTrigger = SwipeTrigger(direction: direction)
                        }
                    }
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
            
            RetroFilmOverlay()
        }
        .onAppear {
            Task { await viewModel.startInspirationMode() }
        }
        .sheet(item: $pendingMovie, onDismiss: {
            resetTrigger.toggle()
        }) { movie in
            RatingSheet(movie: movie, onSelect: { rating in
                pendingMovie = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    viewModel.submitRating(for: movie, rating: rating)
                    withAnimation {
                        if let idx = viewModel.inspirationMovies.firstIndex(where: { $0.id == movie.id }) {
                            viewModel.inspirationMovies.remove(at: idx)
                        }
                    }
                    if viewModel.inspirationMovies.count < 5 {
                        Task { await viewModel.loadInspirationData() }
                    }
                }
            }, onCancel: {
                pendingMovie = nil
            })
        }
    }
    
    private func handleSwipe(movie: Movie, direction: Int) {
        swipeTrigger = nil
        if direction == 0 { pendingMovie = movie }
        else { viewModel.handleInspirationSwipe(movie: movie, direction: direction) }
    }
}
