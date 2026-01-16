//
//  HistoryView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/5.
//
import SwiftUI
import SwiftData
import SDWebImageSwiftUI

struct HistoryView: View {
    @Query(filter: #Predicate<SavedMovie> { $0.isLiked || $0.isDisliked || $0.isNeutral || $0.isWatched },
           sort: [SortDescriptor(\.interactionDate, order: .reverse)])
    private var history: [SavedMovie]
    
    var groupedHistory: [String: [SavedMovie]] {
        Dictionary(grouping: history) { movie in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: movie.interactionDate)
        }
    }
    
    var sortedMonths: [String] {
        groupedHistory.keys.sorted { $0 > $1 }
    }
    
    var body: some View {
        List {
            if history.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无足迹")
                        .retroFont(size: 18, bold: true) // ✅ 应用修复
                        .foregroundColor(.secondary)
                    Text("你看过的、评价过的电影都会显示在这里")
                        .retroFont(size: 12) // ✅ 应用修复
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 50)
                .listRowBackground(Color.clear)
            } else {
                ForEach(sortedMonths, id: \.self) { month in
                    // ✅ Section Header 修复
                    Section(header: Text(formatMonth(month)).retroFont(size: 14, bold: true)) {
                        ForEach(groupedHistory[month] ?? []) { item in
                            NavigationLink(destination: MovieDetailView(movie: item.toMovie)) {
                                LiveHistoryRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("观影足迹")
    }
    
    func formatMonth(_ ym: String) -> String {
        let input = DateFormatter(); input.dateFormat = "yyyy-MM"
        if let date = input.date(from: ym) {
            let output = DateFormatter(); output.dateFormat = "yyyy年 M月"
            return output.string(from: date)
        }
        return ym
    }
}

// 🟢 实时更新的足迹行
struct LiveHistoryRow: View {
    let item: SavedMovie
    @State private var title: String
    @State private var posterURL: URL?
    
    init(item: SavedMovie) {
        self.item = item
        _title = State(initialValue: item.title)
        _posterURL = State(initialValue: item.toMovie.thumbnailURL)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间点
            VStack {
                Text(dayString(from: item.interactionDate))
                    .retroFont(size: 18, bold: true) // ✅ 应用修复
                    .foregroundColor(.primary)
                Text(timeString(from: item.interactionDate))
                    .retroFont(size: 10) // ✅ 应用修复
                    .foregroundColor(.secondary)
            }
            .frame(width: 45) // 稍微加宽一点
            
            // 小海报
            WebImage(url: posterURL)
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 60)
                .cornerRadius(4)
                .clipped()
            
            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .retroFont(size: 14, bold: true) // ✅ 标题完美显示
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    statusBadge(item)
                    if let score = item.voteAverage, score > 0 {
                        Text(String(format: "%.1f", score))
                            .retroFont(size: 10, bold: true) // ✅ 分数
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            if let fresh = try? await TMDBService.shared.fetchMovieDetails(movieId: item.id) {
                self.title = fresh.title
                self.posterURL = fresh.thumbnailURL
            }
        }
    }
    
    @ViewBuilder
    func statusBadge(_ item: SavedMovie) -> some View {
        Group {
            if item.isLiked {
                Label("喜欢", systemImage: "heart.fill").foregroundColor(.red)
            } else if item.isDisliked {
                Label("不喜欢", systemImage: "hand.thumbsdown.fill").foregroundColor(.gray)
            } else if item.isNeutral {
                Label("一般", systemImage: "face.smiling").foregroundColor(.blue)
            } else {
                Label("看过", systemImage: "eye").foregroundColor(.secondary)
            }
        }
        .retroFont(size: 10, bold: true) // ✅ 状态标签
    }
    
    func dayString(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd"; return f.string(from: date)
    }
    func timeString(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}
