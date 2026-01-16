//
//  APIService.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//

import Foundation

// 后端返回的数据结构
struct BackendMovieResponse: Codable {
    let tmdbId: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title
        case overview
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case reason
    }
    
    var toMovie: Movie {
        Movie(
            id: tmdbId,
            title: title,
            overview: overview ?? "",
            posterPath: posterPath,
            releaseDate: releaseDate ?? "",
            genreIds: [],
            voteAverage: voteAverage,
            voteCount: 0,
            adult: false,
            recommendationReason: reason
        )
    }
}

struct AISearchResponse: Codable {
    let results: [BackendMovieResponse]
}

class APIService {
    static let shared = APIService()
    
    // 🟢 请务必确认这里是你的阿里云公网 IP
    private let baseURL = "http://47.243.60.183:3000"
    
    // 1. AI 搜索 (记忆碎片)
    func searchAI(query: String) async throws -> [Movie] {
        // 🟢 核心修复：精准区分繁简中文
        let lang = Locale.preferredLanguages.first ?? "en"
        
        var languageInstruction = ""
        
        // 1. 判断是否为繁体中文 (HK, TW, MO, Hant)
        if lang.contains("Hant") || lang.contains("TW") || lang.contains("HK") || lang.contains("MO") {
            // 强制要求繁体
            languageInstruction = " (请务必使用繁体中文回答)"
        }
        // 2. 判断是否为简体中文
        else if lang.contains("zh") || lang.contains("Hans") || lang.contains("CN") {
            // 明确要求简体 (防止 Gemini 抽风)
            languageInstruction = " (请用简体中文回答)"
        }
        // 3. 其他语言 (默认英文)
        else {
            languageInstruction = " (Please reply in English)"
        }
        
        let finalQuery = query + languageInstruction
        
        print("🚀 [APIService] 准备发起 AI 搜索: \(finalQuery)")
        
        guard let encodedQuery = finalQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/ai-search?q=\(encodedQuery)") else {
            print("❌ [APIService] URL 构造失败")
            throw URLError(.badURL)
        }
        
        print("🔗 [APIService] 请求 URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // 设置超时
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIService] 无效响应")
                throw URLError(.badServerResponse)
            }
            
            print("📡 [APIService] 服务器状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [APIService] 服务器报错")
                throw URLError(.badServerResponse)
            }
            
            // 打印原始 JSON 方便调试
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 [APIService] 服务器返回数据: \(jsonString)")
            }
            
            let decoded = try JSONDecoder().decode(AISearchResponse.self, from: data)
            print("✅ [APIService] 解析成功，共 \(decoded.results.count) 条结果")
            return decoded.results.map { $0.toMovie }
            
        } catch {
            print("❌ [APIService] 请求发生错误: \(error.localizedDescription)")
            throw error
        }
    }
    
    // 2. 今日推荐
    func fetchDailyRecommend() async throws -> Movie {
        // 这里保持 /api/recommend 不变（假设之前这个是通的）
        guard let url = URL(string: "\(baseURL)/api/recommend") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let backendMovie = try JSONDecoder().decode(BackendMovieResponse.self, from: data)
        return backendMovie.toMovie
    }
}
