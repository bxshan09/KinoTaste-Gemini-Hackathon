//
//  MovieCardView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SDWebImageSwiftUI

struct MovieCardView: View {
    let movie: Movie
    var isOnboarding: Bool = false
    @Binding var isDetailMode: Bool
    
    @State private var showOverview: Bool = false
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(movie: Movie, isOnboarding: Bool = false, isDetailMode: Binding<Bool> = .constant(false)) {
        self.movie = movie
        self.isOnboarding = isOnboarding
        self._isDetailMode = isDetailMode
    }
    
    var body: some View {
        cardContent
            .modifier(ConditionalLongPress(active: isOnboarding) {
                feedback.impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showOverview.toggle()
                    isDetailMode = showOverview
                }
            })
    }
    
    var cardContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                WebImage(url: movie.posterURL)
                    .resizable()
                    .indicator(.activity)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                
                if !showOverview {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.2), .black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                
                if showOverview {
                    ZStack {
                        Color.black.opacity(0.9).ignoresSafeArea()
                        
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                Text("剧情简介")
                                    .retroFont(size: 18, bold: true) // ✅
                                Spacer()
                                Button(action: closeOverview) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            
                            ScrollView {
                                Text(movie.overview.isEmpty ? "暂无简介" : movie.overview)
                                    .retroFont(size: 16) // ✅ 简介不再拥挤
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(6)
                            }
                            
                            Spacer()
                            
                            Text("点击关闭")
                                .retroFont(size: 12) // ✅
                                .opacity(0.5).foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(25)
                    }
                    .transition(.opacity)
                    .onTapGesture { closeOverview() }
                    
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer()
                        
                        let tagText = isOnboarding ? movie.genresString : movie.recommendationReason
                        if let text = tagText, !text.isEmpty {
                            Text(LocalizedStringKey(text))
                                .retroFont(size: 10, bold: true) // ✅ 推荐理由标签
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.45, green: 0.75, blue: 0.45).opacity(0.9))
                                .cornerRadius(4)
                        }
                        
                        Text(movie.title)
                            .retroFont(size: 22, bold: true) // ✅ 大标题完美显示
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        HStack(spacing: 8) {
                            if !movie.year.isEmpty {
                                Text(movie.year)
                                    .retroFont(size: 14) // ✅
                                    .fontWeight(.medium)
                                    .opacity(0.8)
                            }
                            
                            let region = !movie.countryString.isEmpty ? movie.countryString : movie.languageString
                            if !region.isEmpty {
                                Text(region)
                                    .retroFont(size: 10, bold: true) // ✅
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            if let score = movie.voteAverage, score > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                                    Text(String(format: "%.1f", score))
                                        .retroFont(size: 14, bold: true) // ✅
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        
                        if isOnboarding {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap")
                                Text("长按看简介")
                                    .retroFont(size: 12) // ✅
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
        }
        .aspectRatio(0.666, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func closeOverview() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showOverview = false
            isDetailMode = false
        }
    }
}

struct ConditionalLongPress: ViewModifier {
    let active: Bool
    let action: () -> Void
    
    func body(content: Content) -> some View {
        if active {
            content.onLongPressGesture(minimumDuration: 0.15, perform: action)
        } else {
            content
        }
    }
}
