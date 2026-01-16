//
//  RatedMoviesView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SwiftData
import SDWebImageSwiftUI

struct RatedMoviesView: View {
    // 🟢 核心修复：Query 谓词。
    // 只有当电影处于以下任一“已评价”状态时才显示。
    // 如果用户点击“待定” (Skip)，viewModel 会将这些 flag 全部设为 false，
    // 从而使该电影立即从列表中被 SwiftData 移除。
    @Query(filter: #Predicate<SavedMovie> { $0.isLiked || $0.isDisliked || $0.isNeutral || $0.isWatched || $0.isIgnored },
           sort: [SortDescriptor(\.interactionDate, order: .reverse)])
    private var allRatedMovies: [SavedMovie]
    
    @State private var filterOption: Int = 0
    
    var filteredMovies: [SavedMovie] {
        switch filterOption {
        case 1: return allRatedMovies.filter { $0.isLiked }
        default: return allRatedMovies
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("筛选", selection: $filterOption) {
                Text("全部评价").tag(0)
                Text("我喜欢的").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            
            List {
                if filteredMovies.isEmpty {
                    Text("暂无相关影片")
                        .retroFont(size: 16, bold: true)
                        .foregroundColor(.secondary)
                        .padding()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredMovies) { savedMovie in
                        // 🟢 传入 autoDismiss: true，确保详情页操作后立即返回，触发列表刷新
                        NavigationLink(destination: MovieDetailView(movie: savedMovie.toMovie, autoDismiss: true)) {
                            LiveRatedRow(savedMovie: savedMovie)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("已评价影片")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LiveRatedRow: View {
    let savedMovie: SavedMovie
    @State private var displayTitle: String
    @State private var displayInfo: String
    @State private var displayPosterURL: URL?
    
    init(savedMovie: SavedMovie) {
        self.savedMovie = savedMovie
        _displayTitle = State(initialValue: savedMovie.title)
        _displayInfo = State(initialValue: savedMovie.toMovie.infoString)
        _displayPosterURL = State(initialValue: savedMovie.toMovie.thumbnailURL)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WebImage(url: displayPosterURL)
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 75)
                .cornerRadius(4)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .retroFont(size: 16, bold: true)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(displayInfo)
                    .retroFont(size: 12)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    if savedMovie.isLiked {
                        Label("喜欢", systemImage: "heart.fill").foregroundColor(.red)
                    } else if savedMovie.isDisliked {
                        Label("不喜欢", systemImage: "hand.thumbsdown.fill").foregroundColor(.gray)
                    } else if savedMovie.isNeutral {
                        Label("无感", systemImage: "face.smiling").foregroundColor(.blue)
                    } else if savedMovie.isIgnored {
                        Label("不想看", systemImage: "eye.slash.fill").foregroundColor(.gray)
                    } else if savedMovie.isWatched {
                        Label("看过", systemImage: "eye").foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(savedMovie.releaseDate?.prefix(4) ?? ""))
                        .foregroundColor(.secondary)
                }
                .retroFont(size: 10, bold: true)
            }
        }
        .padding(.vertical, 4)
        .task {
            if let fresh = try? await TMDBService.shared.fetchMovieDetails(movieId: savedMovie.id) {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.displayTitle = fresh.title
                    self.displayInfo = fresh.infoString
                    self.displayPosterURL = fresh.thumbnailURL
                }
            }
        }
    }
}
