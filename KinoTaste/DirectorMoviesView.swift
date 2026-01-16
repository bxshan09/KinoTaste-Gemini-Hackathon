//
//  DirectorMoviesView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SDWebImageSwiftUI

struct DirectorMoviesView: View {
    let director: Person
    @EnvironmentObject var viewModel: AppViewModel
    @State private var movies: [Movie] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if movies.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无收录作品")
                        .retroFont(size: 16) // ✅
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                Spacer()
            } else {
                List(movies) { movie in
                    NavigationLink(destination: MovieDetailView(movie: movie)) {
                        HStack(alignment: .top, spacing: 12) {
                            WebImage(url: movie.thumbnailURL)
                                .resizable()
                                .indicator(.activity)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 90)
                                .cornerRadius(6)
                                .clipped()
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(movie.title)
                                    .retroFont(size: 16, bold: true) // ✅
                                    .lineLimit(2)
                                
                                HStack {
                                    if let reason = movie.recommendationReason, !reason.isEmpty {
                                        Text(reason)
                                            .retroFont(size: 10, bold: true) // ✅
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.8))
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(movie.year)
                                        .retroFont(size: 12) // ✅
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    if let score = movie.voteAverage {
                                        Text(String(format: "%.1f分", score))
                                            .retroFont(size: 12, bold: true) // ✅
                                            .foregroundColor(.orange)
                                        Text("·")
                                            .foregroundColor(.secondary)
                                    }
                                    Text(movie.infoString)
                                        .retroFont(size: 10) // ✅
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(director.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                self.movies = try await viewModel.fetchPersonWorks(personId: director.id)
            } catch {
                print("Failed to load person works: \(error)")
            }
            self.isLoading = false
        }
    }
}
