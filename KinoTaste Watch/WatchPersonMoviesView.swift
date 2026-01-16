//
//  WatchPersonMoviesView.swift
//  KinoTaste Watch App
//
//  Created by Boxiang Shan on 2026/1/10.
//

import SwiftUI
import SDWebImageSwiftUI

struct WatchPersonMoviesView: View {
    let personId: Int
    let name: String
    
    @StateObject private var viewModel = AppViewModel()
    @State private var movies: [Movie] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if movies.isEmpty {
                Text("暂无相关作品")
                    .foregroundColor(.secondary)
            } else {
                // 🟢 列表视图，不使用大海报
                List(movies) { movie in
                    NavigationLink(destination: WatchMovieDetailView(movie: movie)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(movie.title)
                                .font(.headline)
                                .lineLimit(1)
                            
                            HStack {
                                                            Text(movie.year)
                                                                .foregroundColor(.secondary)
                                                            
                                                            if let role = movie.recommendationReason, !role.isEmpty {
                                                                // 🟢 修复：使用 String(format:) 匹配 Localizable.strings 中的 "· %@"
                                                                Text(String(format: NSLocalizedString("· %@", comment: ""), role))
                                                                    .foregroundColor(.blue)
                                                            }
                                                        }
                            .font(.caption2)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(name)
        .onAppear {
            loadWorks()
        }
    }
    
    private func loadWorks() {
        Task {
            do {
                let works = try await viewModel.fetchPersonWorks(personId: personId)
                self.movies = works
            } catch {}
            self.isLoading = false
        }
    }
}
