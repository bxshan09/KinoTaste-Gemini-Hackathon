//
//  TMDBService.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//

import Foundation

class TMDBService {
    static let shared = TMDBService()
    
    private var apiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String else {
            // 如果你还没配好 plist，暂时可以用回硬编码，建议尽快配置
            return "b8b948c05d8b5b1e760f070e74050b88"
        }
        return key
    }
    
    private var baseURL: String {
        let regionCode = Locale.current.region?.identifier ?? "US"
        if regionCode == "CN" {
            return "https://api.kinotaste.me/3"
        } else {
            return "https://api.kinotaste.me/3"
        }
    }
    
    // 动态获取系统语言 (zh-CN 或 en-US)
    private var apiLanguage: String {
        // 获取用户首选语言列表中的第一个
        guard let lang = Locale.preferredLanguages.first else { return "en-US" }
        
        // 1. 判断是否为繁体中文环境 (Traditional Chinese)
        if lang.contains("Hant") || lang.contains("TW") || lang.contains("HK") || lang.contains("MO") {
            return "zh-TW"
        }
        
        // 2. 判断是否为简体中文环境 (Simplified Chinese)
        if lang.contains("zh") || lang.contains("Hans") || lang.contains("CN") {
            return "zh-CN"
        }
        
        // 3. 默认英文
        return "en-US"
    }
    
    static let genreMap: [Int: String] = [
        28: "动作", 12: "冒险", 16: "动画", 35: "喜剧", 80: "犯罪",
        99: "纪录", 18: "剧情", 10751: "家庭", 14: "奇幻", 36: "历史",
        27: "恐怖", 10402: "音乐", 9648: "悬疑", 10749: "爱情", 878: "科幻",
        10770: "电视电影", 53: "惊悚", 10752: "战争", 37: "西部"
    ]
    
    // 统一注入 language 参数
    private func fetch<T: Decodable>(endpoint: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        
        // 自动注入语言参数
        queryItems.append(URLQueryItem(name: "language", value: apiLanguage))
        
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - API Methods
    
    func fetchRecommendations(
        includeGenres: [Int],
        excludeGenres: [Int],
        withOriginalLanguage: String? = nil,
        withoutKeywords: String? = nil,
        withKeywords: String? = nil,
        withCompanies: String? = nil,
        withPeople: [Int]? = nil,
        releaseDateGte: String? = nil,
        releaseDateLte: String? = nil,
        sortBy: String = "popularity.desc",
        minVoteCount: Int? = nil,
        maxVoteCount: Int? = nil, // 🟢 新增：最大评分人数 (用于筛选冷门片)
        page: Int = 1
    ) async throws -> [Movie] {
        var params: [String: String] = [
            "sort_by": sortBy,
            "page": "\(page)",
            "include_adult": "false",
            "include_video": "false"
        ]
        
        if !includeGenres.isEmpty { params["with_genres"] = includeGenres.map(String.init).joined(separator: ",") }
        if !excludeGenres.isEmpty { params["without_genres"] = excludeGenres.map(String.init).joined(separator: ",") }
        
        if let companies = withCompanies { params["with_companies"] = companies }
        
        if let people = withPeople, !people.isEmpty {
            params["with_people"] = people.map(String.init).joined(separator: ",")
        }
        
        if let gte = releaseDateGte { params["primary_release_date.gte"] = gte }
        if let lte = releaseDateLte { params["primary_release_date.lte"] = lte }
        
        if let lang = withOriginalLanguage { params["with_original_language"] = lang }
        
        if let keywords = withKeywords { params["with_keywords"] = keywords }
        if let noKeywords = withoutKeywords { params["without_keywords"] = noKeywords }
        
        if let minVotes = minVoteCount { params["vote_count.gte"] = String(minVotes) }
        
        // 🟢 处理新增参数
        if let maxVotes = maxVoteCount { params["vote_count.lte"] = String(maxVotes) }
        
        let response: TMDBResponse = try await fetch(endpoint: "/discover/movie", params: params)
        return response.results
    }
    
    func fetchPersonCredits(personId: Int) async throws -> PersonCreditResponse {
        return try await fetch(endpoint: "/person/\(personId)/movie_credits")
    }
    
    func searchMovies(query: String, page: Int = 1) async throws -> [Movie] {
        let response: TMDBResponse = try await fetch(endpoint: "/search/movie", params: [
            "query": query, "page": "\(page)", "include_adult": "false"
        ])
        return response.results
    }
    
    func fetchCredits(movieId: Int) async throws -> CreditsResponse {
        return try await fetch(endpoint: "/movie/\(movieId)/credits")
    }

    func fetchVideos(movieId: Int) async throws -> [Video] {
        let response: VideoResponse = try await fetch(endpoint: "/movie/\(movieId)/videos")
        return response.results
    }
    
    func searchPeople(query: String) async throws -> [Person] {
        let response: TMDBPersonResponse = try await fetch(endpoint: "/search/person", params: ["query": query, "include_adult": "false"])
        return response.results
    }
    
    func fetchMovieDetails(movieId: Int) async throws -> Movie {
        return try await fetch(endpoint: "/movie/\(movieId)")
    }
    
    func fetchImages(movieId: Int) async throws -> [MovieImage] {
        let response: MovieImageResponse = try await fetch(endpoint: "/movie/\(movieId)/images", params: ["include_image_language": "en,null"])
        return response.backdrops
    }
    
    func fetchSimilarMovies(movieId: Int) async throws -> [Movie] {
        let response: TMDBResponse = try await fetch(endpoint: "/movie/\(movieId)/similar")
        return response.results
    }
}
