//
//  WatchMovieDetailView.swift
//  KinoTaste Watch App
//
//  Created by Boxiang Shan on 2026/1/10.
//

import SwiftUI
import SDWebImageSwiftUI

struct WatchMovieDetailView: View {
    @State private var movie: Movie
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isToWatch: Bool = false
    @State private var currentRating: AppViewModel.RatingType? = nil
    @State private var isIgnored: Bool = false
    
    @State private var cast: [Cast] = []
    @State private var crew: [Crew] = []
    
    init(movie: Movie) {
        _movie = State(initialValue: movie)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // 1. 海报 (含评分信息)
                WatchMovieCard(movie: movie)
                
                // 2. 时长
                if !movie.durationString.isEmpty {
                                    // 🟢 修复：使用 String(format:) 匹配 Localizable.strings 中的 "片长: %@"
                                    Text(String(format: NSLocalizedString("片长: %@", comment: ""), movie.durationString))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 2)
                                }
                
                // 3. 操作栏
                HStack(spacing: 0) {
                    // 待看
                    IconButton(icon: isToWatch ? "bookmark.fill" : "bookmark", color: .blue, isSelected: isToWatch) {
                        toggleWatchlist()
                    }
                    Spacer()
                    // 喜欢 (红心)
                    IconButton(icon: "heart.fill", color: .red, isSelected: currentRating == .like) { rate(.like) }
                    Spacer()
                    // 一般 (🟢 修复：改为通用 face.smiling，橙色)
                    IconButton(icon: "face.smiling", color: .orange, isSelected: currentRating == .neutral) { rate(.neutral) }
                    Spacer()
                    // 不喜 (灰手)
                    IconButton(icon: "hand.thumbsdown.fill", color: .gray, isSelected: currentRating == .dislike) { rate(.dislike) }
                    Spacer()
                    // Pass
                    IconButton(icon: "eye.slash.fill", color: .purple, isSelected: isIgnored) { rate(.notInterested) }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                // 4. 简介
                VStack(alignment: .leading, spacing: 4) {
                    Text("剧情简介").font(.caption).bold()
                    Text(movie.overview.isEmpty ? "暂无简介" : movie.overview)
                        .font(.caption2).foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                
                // 5. 演职员
                if !crew.isEmpty {
                    Divider()
                    Text("幕后主创").font(.caption).bold()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(crew) { person in
                                NavigationLink(destination: WatchPersonMoviesView(personId: person.id, name: person.name)) {
                                    PersonHeadshot(name: person.name, url: person.profileURL, role: person.job)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                if !cast.isEmpty {
                    Divider()
                    Text("主演").font(.caption).bold()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(cast.prefix(6)) { actor in
                                NavigationLink(destination: WatchPersonMoviesView(personId: actor.id, name: actor.name)) {
                                    PersonHeadshot(name: actor.name, url: actor.profileURL, role: actor.character)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            checkStatus()
            loadCredits()
        }
    }
    
    // MARK: - 逻辑
    private func rate(_ type: AppViewModel.RatingType) {
        withAnimation {
            if (type == .notInterested && isIgnored) || (currentRating == type) {
                viewModel.undoRating(for: movie)
                currentRating = nil
                isIgnored = false
            } else {
                viewModel.rateMovie(movie: movie, type: type)
                dismiss() // 自动返回
            }
        }
    }
    
    private func toggleWatchlist() {
        if isToWatch { viewModel.deleteFromWatchlist(movie) }
        else { viewModel.rateMovie(movie: movie, type: .addToWatch) }
        isToWatch.toggle()
    }
    
    private func checkStatus() {
        self.isToWatch = viewModel.isMovieToWatch(movie.id)
        self.currentRating = viewModel.checkRating(for: movie.id)
        if let rating = currentRating, rating == .notInterested {
            isIgnored = true
            currentRating = nil
        }
    }
    
    private func loadCredits() {
        Task {
            do {
                let credits = try await TMDBService.shared.fetchCredits(movieId: movie.id)
                self.cast = credits.cast
                var filtered: [Crew] = []
                var seen = Set<Int>()
                let jobMap = ["Director": "导演", "Screenplay": "编剧", "Writer": "编剧", "Director of Photography": "摄影", "Editor": "剪辑"]
                for p in credits.crew {
                    if let cnJob = jobMap[p.job], !seen.contains(p.id) {
                        let newPerson = Crew(id: p.id, name: p.name, originalName: p.originalName, job: cnJob, profilePath: p.profilePath)
                        filtered.append(newPerson)
                        seen.insert(p.id)
                    }
                }
                let priority = ["导演":0, "编剧":1, "摄影":2, "剪辑":3]
                self.crew = filtered.sorted { (priority[$0.job] ?? 99) < (priority[$1.job] ?? 99) }.prefix(6).map{$0}
            } catch {}
        }
    }
}

// 辅助组件
struct IconButton: View {
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? color : .gray)
                .clipShape(Circle())
                .overlay(Circle().stroke(isSelected ? color : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PersonHeadshot: View {
    let name: String
    let url: URL?
    let role: String
    var body: some View {
        VStack {
            WebImage(url: url).resizable().scaledToFill().frame(width: 44, height: 44).background(Color.gray.opacity(0.3)).clipShape(Circle())
            Text(name).font(.system(size: 9)).lineLimit(1).frame(width: 50)
            
            // 🟢 修复：强制转换为 LocalizedStringKey，否则"导演"无法变为"導演"
            Text(LocalizedStringKey(role))
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 50)
        }
    }
}
