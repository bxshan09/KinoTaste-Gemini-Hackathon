//
//  MovieDetailView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SDWebImageSwiftUI

// MARK: - 辅助组件

struct PersonLinkCell: View {
    let personId: Int
    let name: String
    let imageURL: URL?
    let role: String
    
    var body: some View {
        let tempPerson = Person(id: personId, name: name, originalName: nil, knownForDepartment: nil, profilePath: nil, popularity: nil)
        
        NavigationLink(destination: DirectorMoviesView(director: tempPerson)) {
            VStack(spacing: 6) {
                WebImage(url: imageURL)
                    .resizable()
                    .indicator(.activity)
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))
                
                VStack(spacing: 2) {
                    Text(name)
                        .retroFont(size: 10, bold: true)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(width: 80)
                    
                    Text(LocalizedStringKey(role))
                        .retroFont(size: 8)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 80)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LaurelBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "laurel.leading")
            Text("Top Rated")
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
            Image(systemName: "laurel.trailing")
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.yellow.opacity(0.5), lineWidth: 1))
    }
}

struct SearchSourceButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 16))
                Text("找片")
                    .retroFont(size: 14, bold: true)
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(minWidth: 80)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

struct PlayTrailerButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 14))
                Text("预告")
                    .retroFont(size: 14, bold: true)
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(minWidth: 80)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

struct PendingButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                Text("待定")
                    .retroFont(size: 14, bold: true)
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(minWidth: 80)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

struct DetailActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(LocalizedStringKey(title))
                    .retroFont(size: 10, bold: true)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(width: 60, height: 60)
            .background(isActive ? activeColor.opacity(0.15) : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isActive ? activeColor : .secondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? activeColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - 主视图 MovieDetailView

struct MovieDetailView: View {
    @State private var movie: Movie
    @State private var preservedGenres: String = ""
    var autoDismiss: Bool = true
    
    init(movie: Movie, autoDismiss: Bool = true) {
        _movie = State(initialValue: movie)
        _preservedGenres = State(initialValue: movie.genresString)
        self.autoDismiss = autoDismiss
    }
    
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var cast: [Cast] = []
    @State private var director: Crew? = nil
    @State private var writers: [Crew] = []
    @State private var dops: [Crew] = []
    @State private var composers: [Crew] = []
    @State private var editors: [Crew] = []
    
    @State private var stills: [MovieImage] = []
    @State private var showFullScreenGallery = false
    @State private var selectedImageIndex = 0
    
    @State private var currentRating: AppViewModel.RatingType? = nil
    @State private var isToWatch: Bool = false
    @State private var runtimeString: String = ""
    
    private var isGlobalContext: Bool {
        let locale = Locale.current.identifier
        return !locale.contains("CN")
    }
    
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var displayInfoString: String {
        var parts: [String] = []
        if !preservedGenres.isEmpty { parts.append(preservedGenres) }
        else if !movie.genresString.isEmpty { parts.append(movie.genresString) }
        
        let langStr = movie.languageString
        let countryStr = movie.countryString
        
        if movie.originalLanguage == "zh" || movie.originalLanguage == "cn" {
             if !langStr.isEmpty { parts.append(langStr) }
        } else {
            if !countryStr.isEmpty { parts.append(countryStr) }
            if !langStr.isEmpty { parts.append(langStr) }
        }
        return parts.joined(separator: " · ")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // 1. 顶部海报
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        // 海报轮播
                        TabView(selection: $selectedImageIndex) {
                            WebImage(url: movie.posterURL)
                                .resizable()
                                .indicator(.activity)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .tag(0)
                            
                            ForEach(Array(stills.prefix(10).enumerated()), id: \.element) { index, image in
                                WebImage(url: image.url)
                                    .resizable()
                                    .indicator(.activity)
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .tag(index + 1)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .onTapGesture { showFullScreenGallery = true }
                        
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                            .allowsHitTesting(false)
                        
                        // 文字信息区域 (左下)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if let reason = movie.recommendationReason, !reason.isEmpty {
                                    Text(LocalizedStringKey(reason))
                                        .retroFont(size: 10, bold: true)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(6)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if (movie.voteAverage ?? 0) > 8.0 { LaurelBadge() }
                            }
                            
                            // 标题
                            Text(movie.title)
                                .retroFont(size: isIPad ? 40 : 32, bold: true)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                            
                            // 年份 / 时长 / 评分
                            HStack(spacing: 12) {
                                if !movie.year.isEmpty {
                                    Text(movie.year)
                                        .retroFont(size: 14, bold: true)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                if !runtimeString.isEmpty {
                                    Text(runtimeString)
                                        .retroFont(size: 14, bold: true)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                if movie.hasRating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                        Text(movie.scoreText)
                                            .retroFont(size: 16, bold: true)
                                            .foregroundColor(.yellow)
                                    }
                                } else {
                                    Text("暂无评分")
                                        .retroFont(size: 10, bold: true)
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                }
                            }
                            
                            // 类型·地区·语言
                            Text(displayInfoString)
                                .retroFont(size: 14)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                        }
                        // 🟢 修复1：大幅增加左侧 Padding，使其不贴边
                        .padding(.leading, 24)
                        .padding(.bottom, 20)
                        .padding(.trailing, 100)
                        
                        // 按钮组 (右下)
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    PendingButton {
                                        // 待定逻辑：撤销评价 -> 移除待看 -> Skip -> 返回
                                        viewModel.undoRating(for: movie)
                                        if isToWatch { viewModel.deleteFromWatchlist(movie) }
                                        viewModel.skipMovie(movie)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                    
                                    PlayTrailerButton(action: openTrailer)
                                    SearchSourceButton(action: openSourceSearch)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 30)
                            }
                        }
                    }
                }
                .frame(height: isIPad ? 700 : 500)
                
                // 操作按钮组
                HStack(spacing: 15) {
                    Spacer()
                    DetailActionButton(icon: isToWatch ? "bookmark.fill" : "bookmark", title: "待看", isActive: isToWatch, activeColor: .blue, action: toggleWatchlist)
                    DetailActionButton(icon: "heart.fill", title: "喜欢", isActive: currentRating == .like, activeColor: .red, action: { setRating(.like) })
                    DetailActionButton(icon: "face.smiling", title: "一般", isActive: currentRating == .neutral, activeColor: .orange, action: { setRating(.neutral) })
                    DetailActionButton(icon: "hand.thumbsdown", title: "不喜欢", isActive: currentRating == .dislike, activeColor: .gray, action: { setRating(.dislike) })
                    DetailActionButton(icon: "eye.slash", title: "不想看", isActive: currentRating == .notInterested, activeColor: .gray, action: { setRating(.notInterested) })
                    Spacer()
                }
                .padding(.horizontal, 10)
                
                // 简介
                VStack(alignment: .leading, spacing: 8) {
                    Text("剧情简介")
                        .retroFont(size: 18, bold: true)
                    
                    Text(movie.overview.isEmpty ? "暂无简介" : movie.overview)
                        .retroFont(size: 14)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
                
                // 演职员表
                if director != nil || !writers.isEmpty || !dops.isEmpty || !composers.isEmpty || !editors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("幕后主创")
                            .retroFont(size: 16, bold: true)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                if let dir = director { PersonLinkCell(personId: dir.id, name: dir.name, imageURL: dir.profileURL, role: "导演") }
                                ForEach(writers) { writer in PersonLinkCell(personId: writer.id, name: writer.name, imageURL: writer.profileURL, role: "编剧") }
                                ForEach(dops) { dop in PersonLinkCell(personId: dop.id, name: dop.name, imageURL: dop.profileURL, role: "摄影") }
                                ForEach(composers) { comp in PersonLinkCell(personId: comp.id, name: comp.name, imageURL: comp.profileURL, role: "配乐") }
                                ForEach(editors) { ed in PersonLinkCell(personId: ed.id, name: ed.name, imageURL: ed.profileURL, role: "剪辑") }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                if !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("主要演员")
                            .retroFont(size: 16, bold: true)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(cast) { actor in PersonLinkCell(personId: actor.id, name: actor.name, imageURL: actor.profileURL, role: actor.character) }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                if let companies = movie.productionCompanies, !companies.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("制作发行")
                            .retroFont(size: 16, bold: true)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(companies) { company in
                                    if let url = company.logoURL {
                                        VStack {
                                            WebImage(url: url)
                                                .resizable()
                                                .indicator(.activity)
                                                .scaledToFit()
                                                .frame(height: 30)
                                                .colorMultiply(.primary)
                                            
                                            Text(company.name)
                                                .retroFont(size: 8)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    } else {
                                        Text(company.name)
                                            .retroFont(size: 10)
                                            .foregroundColor(.secondary)
                                            .padding(8)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer().frame(height: 40)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: shareMovie) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
            }
        }
        .onAppear {
            checkStatus()
            Task { await loadCredits() }
            Task { await loadDetails() }
            Task { await loadImages() }
        }
        .fullScreenCover(isPresented: $showFullScreenGallery) {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: $selectedImageIndex) {
                    WebImage(url: movie.posterURL)
                        .resizable()
                        .indicator(.activity)
                        .aspectRatio(contentMode: .fit)
                        .tag(0)
                    
                    ForEach(Array(stills.enumerated()), id: \.element) { index, image in
                        WebImage(url: image.originalURL)
                            .resizable()
                            .indicator(.activity)
                            .aspectRatio(contentMode: .fit)
                            .tag(index + 1)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showFullScreenGallery = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
            .onTapGesture { showFullScreenGallery = false }
        }
    }
    
    // MARK: - Logic
    
    private func checkStatus() {
        self.isToWatch = viewModel.isMovieToWatch(movie.id)
        self.currentRating = viewModel.checkRating(for: movie.id)
    }
    
    private func setRating(_ type: AppViewModel.RatingType?) {
        if let type = type {
            viewModel.rateMovie(movie: movie, type: type)
            currentRating = type
            if isToWatch {
                viewModel.deleteFromWatchlist(movie)
                isToWatch = false
            }
            presentationMode.wrappedValue.dismiss()
        } else {
            viewModel.undoRating(for: movie)
            currentRating = nil
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func toggleWatchlist() {
        if isToWatch {
            viewModel.deleteFromWatchlist(movie)
            isToWatch = false
        } else {
            viewModel.rateMovie(movie: movie, type: .addToWatch)
            isToWatch = true
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func loadDetails() async {
        do {
            let fresh = try await TMDBService.shared.fetchMovieDetails(movieId: movie.id)
            await MainActor.run {
                self.movie = fresh
                if let rt = fresh.runtime, rt > 0 {
                    self.runtimeString = fresh.durationString
                }
            }
        } catch {}
    }
    
    private func loadCredits() async {
        do {
            let credits = try await TMDBService.shared.fetchCredits(movieId: movie.id)
            await MainActor.run {
                self.cast = credits.cast
                self.director = credits.crew.first { $0.job == "Director" }
                self.writers = credits.crew.filter { $0.job == "Screenplay" || $0.job == "Writer" }
                self.dops = credits.crew.filter { $0.job == "Director of Photography" }
                self.composers = credits.crew.filter { $0.job == "Original Music Composer" || $0.job == "Composer" }
                self.editors = credits.crew.filter { $0.job == "Editor" }
            }
        } catch {}
    }
    
    private func loadImages() async {
        do {
            let images = try await TMDBService.shared.fetchImages(movieId: movie.id)
            await MainActor.run {
                self.stills = images
            }
        } catch {}
    }
    
    private func shareMovie() {
        let text = "推荐一部电影《\(movie.title)》\n\(movie.overview.prefix(50))..."
        let url = URL(string: "https://www.themoviedb.org/movie/\(movie.id)")!
        let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
    
    private func openSourceSearch() {
        let keyword = "\(movie.title) \(movie.year)"
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if isGlobalContext {
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)+watch+online") {
                UIApplication.shared.open(url)
            }
        } else {
            if let url = URL(string: "https://m.douban.com/search/?query=\(encoded)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openTrailer() {
        var keyword = movie.title
        if movie.year != "N/A" && !movie.year.isEmpty { keyword += " \(movie.year)" }
        keyword += " trailer"
        
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if isGlobalContext {
            if let appUrl = URL(string: "youtube://results?search_query=\(encoded)"),
               let webUrl = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") {
                if UIApplication.shared.canOpenURL(appUrl) {
                    UIApplication.shared.open(appUrl)
                } else {
                    UIApplication.shared.open(webUrl)
                }
            }
        } else {
            let cnKeyword = "\(movie.title) \(movie.year) 预告"
            let cnEncoded = cnKeyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            if let appUrl = URL(string: "bilibili://search?keyword=\(cnEncoded)"),
               let webUrl = URL(string: "https://search.bilibili.com/all?keyword=\(cnEncoded)") {
                if UIApplication.shared.canOpenURL(appUrl) {
                    UIApplication.shared.open(appUrl)
                } else {
                    UIApplication.shared.open(webUrl)
                }
            }
        }
    }
}
