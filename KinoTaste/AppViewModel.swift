//
//  AppViewModel.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI
import SwiftData
import StoreKit
import Combine

#if os(iOS)
import UIKit
#endif

#if os(watchOS)
import WatchKit
#endif

struct CategoryItem: Identifiable, Equatable {
    let id: String
    let name: String
    let type: CategoryType
    let value: String
    let sortGenreId: Int
    
    enum CategoryType {
        case genre
        case keyword
        case language
        case custom
    }
}

@MainActor
class AppViewModel: ObservableObject {
    
    enum SearchMode { case normal, ai }
    @Published var searchMode: SearchMode = .normal
    
    enum AppState { case onboarding, dashboard }
    
    enum RatingType { case like, dislike, neutral, addToWatch, watched, notInterested }
    
    // MARK: - 状态变量
    @Published var showSplash: Bool = true
    @Published var appState: AppState = .onboarding
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var aiIsLoading: Bool = false
    
    @Published var hasAgreedPrivacy: Bool = UserDefaults.standard.bool(forKey: "UserAgreedPrivacy")
    
    @Published var onboardingMovies: [Movie] = []
    @Published var recommendedMovies: [Movie] = []
    
    @Published var isSearching: Bool = false
    
    @Published var normalSearchResults: [Movie] = []
    @Published var aiSearchResults: [Movie] = []
    
    // 记录上一次 AI 搜索的关键词
    @Published var lastAIQuery: String = ""
    
    var currentSearchResults: [Movie] {
        switch searchMode {
        case .normal: return normalSearchResults
        case .ai: return aiSearchResults
        }
    }
    
    @Published var searchPeopleResults: [Person] = []
    @Published var selectedCategory: CategoryItem? = nil
    
    private var modelContext: ModelContext?
    private let worldLanguages = ["ja", "ko", "fr", "de", "it", "es", "th", "hi", "pt", "da", "sv", "fa", "ru", "nl", "pl"]
    
    private let bannedGenres: Set<Int> = [10770]
    private let blockedKeywords = "190678,9826,156372,246237,175657"
    private let bannedTitleKeywords: [String] = [
        "演唱会", "巡演", "巡回", "live in", "concert", "tour",
        "sex", "erotic", "porn", "色情", "三级", "情色", "av",
        "nudity", "hentai", "xxx", "erotica"
    ]
    
    // MARK: - 分类列表
    let categories: [CategoryItem] = [
        CategoryItem(id: "custom-upcoming", name: "📅 即将登场", type: .custom, value: "upcoming", sortGenreId: 0),
        // 🟢 新增：冷门佳片 (Hidden Gems)
        CategoryItem(id: "custom-hidden-gems", name: "💎 冷门佳片", type: .custom, value: "hidden_gems", sortGenreId: 0),
        CategoryItem(id: "custom-healing", name: "☀️ 治愈时光", type: .custom, value: "healing", sortGenreId: 10751),
        CategoryItem(id: "g-10749", name: "💌 遇见爱情", type: .genre, value: "10749", sortGenreId: 10749),
        CategoryItem(id: "g-35", name: "😂 轻松一刻", type: .genre, value: "35", sortGenreId: 35),
        CategoryItem(id: "g-9648", name: "🧠 极致烧脑", type: .genre, value: "9648", sortGenreId: 9648),
        CategoryItem(id: "g-878", name: "🚀 硬核科幻", type: .genre, value: "878", sortGenreId: 878),
        CategoryItem(id: "g-27", name: "👻 惊魂午夜", type: .genre, value: "27", sortGenreId: 27),
        
        CategoryItem(id: "lang-yue", name: "🇭🇰 港产岁月", type: .language, value: "cn", sortGenreId: 28),
        CategoryItem(id: "g-16", name: "🖌️ 视觉动画", type: .genre, value: "16", sortGenreId: 16),
        CategoryItem(id: "g-80", name: "🔫 冷硬犯罪", type: .genre, value: "80", sortGenreId: 80),
        CategoryItem(id: "k-9672", name: "📖 真实事件", type: .keyword, value: "9672", sortGenreId: 18)
    ]
    
    var sortedCategories: [CategoryItem] {
        let scores = genreScores
        return categories.sorted { item1, item2 in
            if item1.value == "upcoming" || item1.value == "hidden_gems" { return true }
            if item2.value == "upcoming" || item2.value == "hidden_gems" { return false }
            
            let score1 = scores[item1.sortGenreId] ?? 0
            let score2 = scores[item2.sortGenreId] ?? 0
            return score1 > score2
        }
    }
    
    // MARK: - 动态计算属性
    var seenMovieIds: Set<Int> {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<SavedMovie>(
            predicate: #Predicate { $0.isLiked || $0.isDisliked || $0.isNeutral || $0.isWatched || $0.isIgnored }
        )
        let saved = (try? context.fetch(descriptor)) ?? []
        return Set(saved.map { $0.id })
    }
    
    var likedMovies: [SavedMovie] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<SavedMovie>(
            predicate: #Predicate { $0.isLiked },
            sortBy: [SortDescriptor(\.interactionDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    var likedMovieIds: [Int] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { $0.isLiked })
        return (try? context.fetch(descriptor))?.map { $0.id } ?? []
    }
    
    var toWatchList: [Movie] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<SavedMovie>(
            predicate: #Predicate { $0.isToWatch },
            sortBy: [SortDescriptor(\.interactionDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map { $0.toMovie } ?? []
    }
    
    var genreScores: [Int: Int] {
        guard let context = modelContext else { return [:] }
        let descriptor = FetchDescriptor<SavedMovie>(
            predicate: #Predicate { $0.isLiked || $0.isDisliked || $0.isNeutral || $0.isToWatch || $0.isIgnored }
        )
        let saved = (try? context.fetch(descriptor)) ?? []
        
        var scores: [Int: Int] = [:]
        let now = Date()
        let calendar = Calendar.current
        
        for movie in saved {
            var weight = 0.0
            if movie.isLiked { weight = 5.0 }
            else if movie.isDisliked { weight = -5.0 }
            else if movie.isIgnored { weight = -3.0 }
            else if movie.isToWatch { weight = 3.0 }
            else if movie.isNeutral { weight = 0.5 }
            
            let daysSince = calendar.dateComponents([.day], from: movie.interactionDate, to: now).day ?? 0
            if daysSince < 30 { weight *= 1.5 }
            else if daysSince > 90 { weight *= 0.5 }
            
            for genre in movie.genreIds { scores[genre, default: 0] += Int(weight) }
        }
        return scores
    }
    
    var seenCount: Int { seenMovieIds.count }
    
    // MARK: - 初始化
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        if hasAgreedPrivacy {
            checkAppState()
        } else {
            self.showSplash = false
        }
    }
    
    func toggleWatchlistContext(_ movie: Movie) {
        if isMovieToWatch(movie.id) {
            deleteFromWatchlist(movie)
        } else {
            rateMovie(movie: movie, type: .addToWatch)
        }
    }
    
    func agreePrivacy() {
        self.hasAgreedPrivacy = true
        UserDefaults.standard.set(true, forKey: "UserAgreedPrivacy")
        checkAppState()
    }
    
    private func checkAppState() {
        Task {
            let isDashboard = seenCount >= 10
            async let minDisplayTime = try? Task.sleep(nanoseconds: 800_000_000)
            async let dataLoading: Void = {
                if isDashboard {
                    await refreshRecommendations(reset: true)
                } else {
                    await loadOnboardingMovies()
                }
            }()
            
            _ = await (minDisplayTime, dataLoading)
            
            self.appState = isDashboard ? .dashboard : .onboarding
            withAnimation(.easeOut(duration: 0.3)) { self.showSplash = false }
        }
    }
    
    func isMovieLiked(_ movieId: Int) -> Bool { return likedMovieIds.contains(movieId) }
    func isMovieToWatch(_ movieId: Int) -> Bool { return toWatchList.contains(where: { $0.id == movieId }) }
    
    func checkRating(for movieId: Int) -> RatingType? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { $0.id == movieId })
        guard let saved = try? context.fetch(descriptor).first else { return nil }
        
        if saved.isLiked { return .like }
        if saved.isDisliked { return .dislike }
        if saved.isNeutral { return .neutral }
        if saved.isIgnored { return .notInterested }
        return nil
    }
    
    // MARK: - 交互逻辑
    
    func skipMovie(_ movie: Movie) {
        withAnimation {
            if let index = onboardingMovies.firstIndex(where: { $0.id == movie.id }) {
                onboardingMovies.remove(at: index)
            }
            if let index = inspirationMovies.firstIndex(where: { $0.id == movie.id }) {
                inspirationMovies.remove(at: index)
            }
            if let index = recommendedMovies.firstIndex(where: { $0.id == movie.id }) {
                recommendedMovies.remove(at: index)
            }
        }
        
        if appState == .onboarding && onboardingMovies.isEmpty {
            completeOnboarding()
        }
        
        if inspirationMovies.count < 5 {
            Task { await loadInspirationData() }
        }
    }
    
    func rateMovie(movie: Movie, type: RatingType) {
        guard let context = modelContext else { return }
        let movieId = movie.id
        let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { $0.id == movieId })
        let existing = try? context.fetch(descriptor).first
        let SavedMovie = existing ?? SavedMovie(from: movie)
        if existing == nil { context.insert(SavedMovie) }
        SavedMovie.interactionDate = Date()
        
        SavedMovie.isLiked = false
        SavedMovie.isDisliked = false
        SavedMovie.isNeutral = false
        SavedMovie.isIgnored = false
        
        switch type {
        case .like:
            SavedMovie.isLiked = true; SavedMovie.isWatched = true; SavedMovie.isToWatch = false
        case .dislike:
            SavedMovie.isDisliked = true; SavedMovie.isWatched = true; SavedMovie.isToWatch = false
        case .neutral:
            SavedMovie.isNeutral = true; SavedMovie.isWatched = true; SavedMovie.isToWatch = false
        case .notInterested:
            SavedMovie.isIgnored = true; SavedMovie.isWatched = false; SavedMovie.isToWatch = false
        case .addToWatch:
            SavedMovie.isToWatch = true
        case .watched:
            SavedMovie.isWatched = true; SavedMovie.isToWatch = false
        }
        
        try? context.save()
        
        if appState == .dashboard && !isSearching {
            removeFromRecommendations(movie)
        }
        
        if type == .like { checkAndAskForReview() }
    }
    
    func removeFromRecommendations(_ movie: Movie) {
        withAnimation {
            recommendedMovies.removeAll { $0.id == movie.id }
        }
    }
    
    func undoRating(for movie: Movie) {
        guard let context = modelContext else { return }
        let movieId = movie.id
        let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { $0.id == movieId })
        
        if let SavedMovie = try? context.fetch(descriptor).first {
            SavedMovie.isLiked = false
            SavedMovie.isDisliked = false
            SavedMovie.isNeutral = false
            SavedMovie.isIgnored = false
            SavedMovie.isWatched = false
            try? context.save()
        }
    }
    
    func deleteFromWatchlist(_ movie: Movie) {
        guard let context = modelContext else { return }
        let movieId = movie.id
        let descriptor = FetchDescriptor<SavedMovie>(predicate: #Predicate { $0.id == movieId })
        
        if let SavedMovie = try? context.fetch(descriptor).first {
            SavedMovie.isToWatch = false
            try? context.save()
        }
    }
    
    func deleteFromWatchlist(_ SavedMovie: SavedMovie) {
        SavedMovie.isToWatch = false
        try? modelContext?.save()
    }
    
    func handleQuickSwipe(movie: Movie, direction: Int) {
        switch direction {
        case 0: rateMovie(movie: movie, type: .watched); removeCardFromList(movie)
        case 1: rateMovie(movie: movie, type: .notInterested); removeCardFromList(movie)
        case 2: rateMovie(movie: movie, type: .addToWatch); removeCardFromList(movie)
        default: break
        }
    }
    
    func submitRating(for movie: Movie, rating: RatingType) {
        rateMovie(movie: movie, type: rating)
        removeCardFromList(movie)
    }
    
    private func removeCardFromList(_ movie: Movie) {
        withAnimation {
            if let index = onboardingMovies.firstIndex(where: { $0.id == movie.id }) { onboardingMovies.remove(at: index) }
        }
        if appState == .onboarding && onboardingMovies.isEmpty { completeOnboarding() }
    }
    
    func requeueMovie(_ movie: Movie) {
        withAnimation {
            if let index = onboardingMovies.firstIndex(where: { $0.id == movie.id }) {
                let item = onboardingMovies.remove(at: index)
                onboardingMovies.append(item)
            }
        }
    }
    
    // MARK: - 灵感/盲盒模式
    @Published var inspirationMovies: [Movie] = []
    
    func startInspirationMode() async {
        if inspirationMovies.count < 3 {
            await loadInspirationData()
        }
    }
    
    func loadInspirationData() async {
        isLoading = true
        do {
            async let b1 = TMDBService.shared.fetchRecommendations(
                includeGenres: [], excludeGenres: [], sortBy: "vote_average.desc", minVoteCount: 500, page: Int.random(in: 1...20)
            )
            async let b2 = TMDBService.shared.fetchRecommendations(
                includeGenres: [], excludeGenres: [], sortBy: "popularity.desc", page: Int.random(in: 1...10)
            )
            async let b3 = TMDBService.shared.fetchRecommendations(
                includeGenres: [], excludeGenres: [], sortBy: "vote_average.desc", minVoteCount: 100, page: Int.random(in: 1...30)
            )
            
            let (r1, r2, r3) = try await (b1, b2, b3)
            var pool = r1 + r2 + r3
            pool.shuffle()
            
            let existingIds = seenMovieIds.union(Set(toWatchList.map { $0.id }))
            let filtered = pool.filter { !existingIds.contains($0.id) && isValidMovie($0) }
            
            var uniqueMovies: [Movie] = []
            var seenIds = Set<Int>()
            let currentInspirationIds = Set(inspirationMovies.map { $0.id })
            
            for m in filtered {
                if !seenIds.contains(m.id) && !currentInspirationIds.contains(m.id) {
                    // 使用本地化 key
                    let reasons = [
                        localized("✨ 灵感推荐"),
                        localized("🎲 盲盒惊喜"),
                        localized("🎬 值得一试"),
                        localized("🍿 也就是看部电影的事")
                    ]
                    uniqueMovies.append(addReason(m, reasons.randomElement()!))
                    seenIds.insert(m.id)
                }
            }
            
            await MainActor.run {
                self.inspirationMovies.append(contentsOf: uniqueMovies)
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
    
    func handleInspirationSwipe(movie: Movie, direction: Int) {
        if direction != 0 { handleQuickSwipe(movie: movie, direction: direction) }
        withAnimation {
            if let index = inspirationMovies.firstIndex(where: { $0.id == movie.id }) {
                inspirationMovies.remove(at: index)
            }
        }
        if inspirationMovies.count < 5 {
            Task { await loadInspirationData() }
        }
    }
    
    // MARK: - 搜索逻辑
    
    // 1. 普通搜索
    func performNormalSearch(query: String) async {
        guard !query.isEmpty else { return }
        await MainActor.run {
            isSearching = true
            isLoading = true
            errorMessage = nil
            self.normalSearchResults = []
            self.searchPeopleResults = []
        }
        
        do {
            async let fetchMovies = TMDBService.shared.searchMovies(query: query)
            async let fetchPeople = TMDBService.shared.searchPeople(query: query)
            let (movieResults, peopleResults) = try await (fetchMovies, fetchPeople)
            
            await MainActor.run {
                self.searchPeopleResults = peopleResults
                self.normalSearchResults = movieResults.filter { $0.posterPath != nil }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "搜索失败，请检查网络" // Key needed
            }
        }
    }
    
    // 2. 记忆碎片搜索
    func performAISearch(query: String) async {
        guard !query.isEmpty else { return }
        
        print("🧠 [ViewModel] 开始记忆碎片搜索: \(query)")
        
        await MainActor.run {
            self.isSearching = true
            self.isLoading = true
            self.aiSearchResults = []
            self.searchPeopleResults = []
            self.errorMessage = nil
            self.lastAIQuery = query
        }
        
        do {
            let aiRawResults = try await APIService.shared.searchAI(query: query)
            
            var verifiedMovies: [Movie] = []
            
            await withTaskGroup(of: Movie?.self) { group in
                for aiMovie in aiRawResults {
                    group.addTask {
                        let realMatches = try? await TMDBService.shared.searchMovies(query: aiMovie.title)
                        
                        if var realMovie = realMatches?.first(where: { $0.posterPath != nil }) {
                            realMovie.recommendationReason = aiMovie.recommendationReason
                            return realMovie
                        }
                        return nil
                    }
                }
                
                for await result in group {
                    if let m = result {
                        verifiedMovies.append(m)
                    }
                }
            }
            
            await MainActor.run {
                if verifiedMovies.isEmpty {
                    self.errorMessage = "未能在记忆中找到匹配的碎片" // Key needed
                } else {
                    let uniqueMovies = Array(Set(verifiedMovies.map { $0.id })).compactMap { id in
                        verifiedMovies.first(where: { $0.id == id })
                    }
                    self.aiSearchResults = uniqueMovies
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "连接超时 请稍后再试" // Key needed
            }
        }
    }
    
    func clearSearch() {
        isSearching = false
        normalSearchResults = []
        aiSearchResults = []
        searchPeopleResults = [] // 清空残留
        errorMessage = nil
        isLoading = false
        lastAIQuery = ""
    }
    
    func fetchPersonWorks(personId: Int) async throws -> [Movie] {
        let credits = try await TMDBService.shared.fetchPersonCredits(personId: personId)
        var movies: [Movie] = []
        var addedIds: Set<Int> = []
        
        let jobPriority = [
            "Director": 1, "Screenplay": 2, "Writer": 2,
            "Director of Photography": 3, "Original Music Composer": 3, "Composer": 3, "Editor": 3,
            "Producer": 4
        ]
        
        let sortedCrew = credits.crew.sorted {
            let p1 = jobPriority[$0.job ?? ""] ?? 99
            let p2 = jobPriority[$1.job ?? ""] ?? 99
            return p1 < p2
        }
        
        for item in sortedCrew {
            if !addedIds.contains(item.id) {
                var reason = item.job ?? "幕后"
                switch reason {
                case "Director": reason = localized("导演")
                case "Screenplay", "Writer": reason = localized("编剧")
                case "Director of Photography": reason = localized("摄影")
                case "Original Music Composer", "Composer": reason = localized("配乐")
                case "Editor": reason = localized("剪辑")
                case "Producer", "Executive Producer": reason = localized("监制")
                default: if jobPriority[item.job ?? ""] == nil { continue }
                }
                movies.append(item.toMovie(reason: reason))
                addedIds.insert(item.id)
            }
        }
        
        let sortedCast = credits.cast.sorted { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) }
        for item in sortedCast {
            if !addedIds.contains(item.id) {
                let charName = item.character ?? ""
                let reason = charName.isEmpty ? localized("主演") : localized("饰 %@", charName)
                movies.append(item.toMovie(reason: reason))
                addedIds.insert(item.id)
            }
        }
        
        return movies.filter { $0.posterPath != nil && !$0.title.isEmpty }
    }
    
    private func processAndAssignMovies(_ movies: [Movie], currentSeen: Set<Int>, currentWatch: [Int], reset: Bool) {
        let validPool = movies.filter { isValidMovie($0) && $0.posterPath != nil && !currentSeen.contains($0.id) && !currentWatch.contains($0.id) }
        
        var uniqueMovies: [Movie] = []
        for m in validPool { if !uniqueMovies.contains(where: { $0.id == m.id }) { uniqueMovies.append(m) } }
        
        let finalList: [Movie]
        if selectedCategory?.value == "upcoming" {
            finalList = uniqueMovies
        } else {
            finalList = uniqueMovies.shuffled()
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            if reset { self.recommendedMovies = Array(finalList.prefix(15)) }
            else { self.recommendedMovies.append(contentsOf: finalList.filter { m in !self.recommendedMovies.contains(where: { $0.id == m.id }) }) }
        }
    }
    
    func changeCategory(to item: CategoryItem?) async {
        if selectedCategory != item { selectedCategory = item; await refreshRecommendations(reset: true) }
    }
    
    func refreshRecommendations(reset: Bool = true) async {
        withAnimation {
            isLoading = true
            if reset { errorMessage = nil; recommendedMovies = [] }
        }
        
        defer { withAnimation { isLoading = false } }
        let currentSeen = seenMovieIds; let currentWatch = toWatchList.map { $0.id }
        if let category = selectedCategory {
            do {
                var fetchedMovies: [Movie] = []
                
                switch category.type {
                case .custom:
                    if category.value == "upcoming" {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                        let future = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
                        
                        fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                            includeGenres: [], excludeGenres: [],
                            releaseDateGte: formatter.string(from: tomorrow),
                            releaseDateLte: formatter.string(from: future),
                            sortBy: "popularity.desc",
                            minVoteCount: 0,
                            page: Int.random(in: 1...2)
                        )
                    }
                    else if category.value == "healing" {
                        fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                            includeGenres: [10751],
                            excludeGenres: [27, 53, 80],
                            sortBy: "vote_average.desc",
                            minVoteCount: 100,
                            page: Int.random(in: 1...3)
                        )
                        let more = try await TMDBService.shared.fetchRecommendations(
                            includeGenres: [10402],
                            excludeGenres: [27, 53],
                            sortBy: "vote_average.desc",
                            minVoteCount: 100,
                            page: 1
                        )
                        fetchedMovies.append(contentsOf: more)
                    }
                    // 🟢 新增：冷门佳片 (Hidden Gems)
                    else if category.value == "hidden_gems" {
                        fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                            includeGenres: [],
                            excludeGenres: [10770], // 排除电视电影
                            sortBy: "vote_average.desc", // 按评分排序
                            minVoteCount: 100,  // 最少 100 人评价 (避免数据太假)
                            maxVoteCount: 2500, // 最多 2500 人评价 (定义为冷门)
                            page: Int.random(in: 1...5)
                        )
                    }
                    
                case .genre:
                    if let val = Int(category.value) {
                        if val == 10749 {
                            fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                                includeGenres: [val], excludeGenres: [27, 53],
                                withoutKeywords: blockedKeywords,
                                sortBy: "popularity.desc",
                                minVoteCount: 100,
                                page: Int.random(in: 1...3)
                            )
                        }
                        else if val == 35 {
                            fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                                includeGenres: [val], excludeGenres: [27, 53, 80],
                                page: Int.random(in: 1...3)
                            )
                        }
                        else if val == 27 { // Horror
                            fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                                includeGenres: [val],
                                excludeGenres: [10751, 16, 10770],
                                sortBy: "popularity.desc",
                                minVoteCount: 300,
                                page: Int.random(in: 1...3)
                            )
                        }
                        else {
                            fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                                includeGenres: [val], excludeGenres: [],
                                page: Int.random(in: 1...3)
                            )
                        }
                    }
                    
                case .keyword:
                    fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                        includeGenres: [], excludeGenres: [],
                        withKeywords: category.value,
                        page: Int.random(in: 1...3)
                    )
                    
                case .language:
                    fetchedMovies = try await TMDBService.shared.fetchRecommendations(
                        includeGenres: [], excludeGenres: [],
                        withOriginalLanguage: category.value,
                        page: Int.random(in: 1...3)
                    )
                }
                
                let tagName = NSLocalizedString(category.name, comment: "")
                var combined: [Movie] = []
                for m in fetchedMovies { combined.append(self.addReason(m, tagName)) }
                
                if combined.isEmpty {
                    self.errorMessage = "该分类暂时没有更多影片" // Key needed
                } else {
                    processAndAssignMovies(combined, currentSeen: currentSeen, currentWatch: currentWatch, reset: reset)
                }
                
            } catch { if reset { self.errorMessage = localized("网络不佳，无法获取该类影片") } }
        } else {
            await performSmartRecommendation(reset: reset, currentSeen: currentSeen, currentWatch: currentWatch)
        }
    }
    
    private func performSmartRecommendation(reset: Bool, currentSeen: Set<Int>, currentWatch: [Int]) async {
        let scores = genreScores
        let hatedGenres = scores.filter { $0.value <= -5 }.map { $0.key }
        let topGenreIds = scores.filter { $0.value > 0 }.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let favoriteGenreId = topGenreIds.first
        
        let recentLikes = likedMovies
        let toWatch = toWatchList
        
        let seedMovie = recentLikes.prefix(5).randomElement()?.toMovie
        
        var seedTitle = ""
        // 核心修复：联网获取种子电影的最新本地化标题
        if let s = seedMovie {
            let t = s.title
            seedTitle = t.count > 6 ? String(t.prefix(5)) + "..." : t
            
            if let freshSeed = try? await TMDBService.shared.fetchMovieDetails(movieId: s.id) {
                let freshTitle = freshSeed.title
                seedTitle = freshTitle.count > 6 ? String(freshTitle.prefix(5)) + "..." : freshTitle
            }
        }
        
        let currentSeenCount = seenCount
        
        do {
            async let slotSimilar = (seedMovie != nil) ? (try? await TMDBService.shared.fetchSimilarMovies(movieId: seedMovie!.id))?.prefix(2).map{addReason($0, localized("类似《%@》", seedTitle))} ?? [] : []
            
            async let slotPerson: [Movie] = {
                let seedPool = (recentLikes.prefix(5).map { $0.toMovie } + toWatch.prefix(5))
                guard let seed = seedPool.randomElement() else { return [] }
                guard let credits = try? await TMDBService.shared.fetchCredits(movieId: seed.id) else { return [] }
                
                let genreFilter = topGenreIds.isEmpty ? [] : [topGenreIds.first!]
                
                let useDirector = Bool.random()
                if useDirector, let director = credits.crew.first(where: { $0.job == "Director" }) {
                    return (try? await TMDBService.shared.fetchRecommendations(
                        includeGenres: genreFilter,
                        excludeGenres: hatedGenres,
                        withPeople: [director.id],
                        page: 1
                    ))?.prefix(2).map { addReason($0, localized("%@ · 风格精选", director.name)) } ?? []
                } else if let actor = credits.cast.first {
                    return (try? await TMDBService.shared.fetchRecommendations(
                        includeGenres: genreFilter,
                        excludeGenres: hatedGenres,
                        withPeople: [actor.id],
                        page: 1
                    ))?.prefix(2).map { addReason($0, localized("%@ · 风格精选", actor.name)) } ?? []
                }
                return []
            }()
            
            async let slotFavoriteGenre: [Movie] = {
                guard let favId = favoriteGenreId else { return [] }
                
                let estimatedPage = (currentSeenCount / 20) + 1
                let queryPage = Int.random(in: 1...max(3, estimatedPage + 2))
                
                let results = (try? await TMDBService.shared.fetchRecommendations(
                    includeGenres: [favId],
                    excludeGenres: hatedGenres,
                    sortBy: "vote_average.desc",
                    minVoteCount: 1000,
                    page: queryPage
                ))?.prefix(3) ?? []
                
                return results.map { m in
                    if let score = m.voteAverage, score >= 8.5 { return addReason(m, localized("口碑神作")) }
                    else if let votes = m.voteCount, votes < 3000 { return addReason(m, localized("冷门佳片")) }
                    else { return addReason(m, localized("高分精选")) }
                }
            }()
            
            let selectedLangs = worldLanguages.shuffled().prefix(5)
            var mixedWorldMovies: [Movie] = []
            
            await withTaskGroup(of: [Movie].self) { group in
                for lang in selectedLangs {
                    group.addTask {
                        let res = try? await TMDBService.shared.fetchRecommendations(
                            includeGenres: [], excludeGenres: hatedGenres,
                            withOriginalLanguage: lang, minVoteCount: 300,
                            page: Int.random(in: 1...2)
                        )
                        let raw = res ?? []
                        let langName = Locale.current.localizedString(forIdentifier: lang) ?? "外语"
                        return raw.prefix(2).map { self.addReason($0, self.localized("高分 · %@", langName)) }
                    }
                }
                for await movies in group {
                    mixedWorldMovies.append(contentsOf: movies)
                }
            }
            mixedWorldMovies.shuffle()
            
            async let slotChinese = try? await TMDBService.shared.fetchRecommendations(includeGenres: [], excludeGenres: hatedGenres, withOriginalLanguage: "zh", page: Int.random(in: 1...5))
            
            let (rSimilar, rPerson, rFavorite, rChinese) = await (slotSimilar, slotPerson, slotFavoriteGenre, slotChinese ?? [])
            
            var combined: [Movie] = []
            combined.append(contentsOf: rFavorite)
            combined.append(contentsOf: rSimilar)
            combined.append(contentsOf: rPerson)
            combined.append(contentsOf: rChinese.prefix(3).map { addReason($0, localized("热门华语")) })
            combined.append(contentsOf: mixedWorldMovies)
            
            processAndAssignMovies(combined, currentSeen: currentSeen, currentWatch: currentWatch, reset: reset)
        } catch {}
    }
    
    func loadOnboardingMovies() async {
        isLoading = true; errorMessage = nil;
        defer { isLoading = false }
        
        async let tTopRated = (try? await TMDBService.shared.fetchRecommendations(includeGenres: [], excludeGenres: [], sortBy: "vote_average.desc", minVoteCount: 3000, page: 1)) ?? []
        async let tPopular = (try? await TMDBService.shared.fetchRecommendations(includeGenres: [], excludeGenres: [], sortBy: "popularity.desc", minVoteCount: 1000, page: Int.random(in: 1...5))) ?? []
        async let tChinese = (try? await TMDBService.shared.fetchRecommendations(includeGenres: [], excludeGenres: [], withOriginalLanguage: "zh", sortBy: "vote_average.desc", minVoteCount: 500, page: 1)) ?? []
        
        let (rTop, rPop, rChinese) = await (tTopRated, tPopular, tChinese)
        let mixed = (rTop + rPop + rChinese).filter { isValidMovie($0) }
        
        if mixed.isEmpty { self.errorMessage = localized("初始化失败"); return }
        let processed = mixed.map { self.addReason($0, $0.genresString) }
        self.onboardingMovies = Array(Set(processed)).shuffled().prefix(50).map { $0 }
    }
    
    func completeOnboardingEarly() { completeOnboarding() }
    private func completeOnboarding() { isLoading = true; appState = .dashboard; Task { await refreshRecommendations() } }
    nonisolated private func addReason(_ movie: Movie, _ reason: String) -> Movie { var m = movie; m.recommendationReason = reason; return m }
    
    nonisolated private func generateBasicInfo(for movie: Movie) -> String {
        var tags: [String] = []
        if let score = movie.voteAverage, score > 0 { tags.append(String(format: "%.1f分", score)) }
        let region = !movie.countryString.isEmpty ? movie.countryString : movie.languageString
        if !region.isEmpty { tags.append(region) }
        return tags.joined(separator: " · ")
    }
    
    private func isValidMovie(_ movie: Movie) -> Bool {
        if movie.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if movie.isAdult { return false }
        if selectedCategory?.value == "upcoming" { return true }
        
        if let score = movie.voteAverage, score < 4.0 { return false }
        if let votes = movie.voteCount, votes < 50 { return false }
        if let gIds = movie.genreIds, !bannedGenres.isDisjoint(with: gIds) { return false }
        let titleLower = movie.title.lowercased()
        for keyword in bannedTitleKeywords { if titleLower.contains(keyword) { return false } }
        return true
    }
    func resetApp() { try? modelContext?.delete(model: SavedMovie.self); appState = .onboarding; Task { await loadOnboardingMovies() } }
    func retry() { errorMessage = nil; if appState == .onboarding { Task { await loadOnboardingMovies() } } else { Task { await refreshRecommendations() } } }
    
    func triggerFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    private func checkAndAskForReview() {
        if [20, 50, 100].contains(likedMovieIds.count) { requestReview() }
    }
    
    func requestReview() {
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
        #endif
    }
    
    nonisolated private func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        if args.isEmpty { return format }
        return String(format: format, arguments: args)
    }
}
