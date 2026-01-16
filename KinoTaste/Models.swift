//
//  Models.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//

import Foundation
import SwiftData

// MARK: - 🟢 动态域名配置
private struct ImageDomainConfig {
    static var baseURL: String {
        let region = Locale.current.region?.identifier ?? "US"
        if region == "CN" {
            return "https://api.kinotaste.me/t/p/"
        } else {
            return "https://api.kinotaste.me/t/p/"
        }
    }
}

// MARK: - API 基础响应结构
struct TMDBResponse: Codable { let results: [Movie] }
struct TMDBPersonResponse: Codable { let results: [Person] }
struct VideoResponse: Codable { let results: [Video] }
struct MovieImageResponse: Codable { let backdrops: [MovieImage]; let posters: [MovieImage] }
struct KeywordResponse: Codable { let keywords: [Keyword] }

struct Video: Codable { let key, site, type: String }
struct Keyword: Identifiable, Codable { let id: Int; let name: String }

struct MovieImage: Identifiable, Codable, Hashable {
    let filePath: String
    var id: String { filePath }
    var url: URL? { URL(string: "\(ImageDomainConfig.baseURL)w780\(filePath)") }
    var originalURL: URL? { URL(string: "\(ImageDomainConfig.baseURL)original\(filePath)") }
    enum CodingKeys: String, CodingKey { case filePath = "file_path" }
}

struct ProductionCompany: Identifiable, Codable, Hashable {
    let id: Int; let name: String; let logoPath: String?; let originCountry: String?
    var logoURL: URL? { guard let p = logoPath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w200\(p)") }
    enum CodingKeys: String, CodingKey { case id, name, logoPath = "logo_path", originCountry = "origin_country" }
}

// MARK: - 影人相关
struct PersonCreditResponse: Codable { let cast: [PersonMovieCredit]; let crew: [PersonMovieCredit] }

struct PersonMovieCredit: Identifiable, Codable {
    let id: Int; let title: String; let posterPath: String?; let overview: String; let releaseDate: String?
    let genreIds: [Int]?; let voteAverage: Double?; let voteCount: Int?; let adult: Bool?
    let originCountry: [String]?; let originalLanguage: String?; let job: String?; let character: String?
    
    func toMovie(reason: String? = nil) -> Movie {
        Movie(id: id, title: title, overview: overview, posterPath: posterPath, releaseDate: releaseDate ?? "", genreIds: genreIds, recommendationReason: reason)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, job, character, releaseDate = "release_date", posterPath = "poster_path", genreIds = "genre_ids", voteAverage = "vote_average", voteCount = "vote_count", adult, originCountry = "origin_country", originalLanguage = "original_language"
    }
}

struct Person: Identifiable, Codable, Hashable {
    let id: Int; let name: String; let originalName: String?; let knownForDepartment: String?; let profilePath: String?; let popularity: Double?
    var profileURL: URL? { guard let p = profilePath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w200\(p)") }
    enum CodingKeys: String, CodingKey { case id, name, popularity, originalName = "original_name", knownForDepartment = "known_for_department", profilePath = "profile_path" }
}

struct CreditsResponse: Codable { let cast: [Cast]; let crew: [Crew] }

struct Cast: Identifiable, Codable, Hashable {
    let id: Int; let name: String; let originalName: String?; let character: String; let profilePath: String?
    var profileURL: URL? { guard let p = profilePath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w200\(p)") }
    enum CodingKeys: String, CodingKey { case id, name, character, originalName = "original_name", profilePath = "profile_path" }
}

struct Crew: Identifiable, Codable, Hashable {
    let id: Int; let name: String; let originalName: String?; let job: String; let profilePath: String?
    var profileURL: URL? { guard let p = profilePath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w200\(p)") }
    enum CodingKeys: String, CodingKey { case id, name, job, originalName = "original_name", profilePath = "profile_path" }
}

// MARK: - 核心电影模型

struct Movie: Identifiable, Codable, Equatable, Hashable {
    let uuid = UUID()
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String
    let genreIds: [Int]?
    let voteAverage: Double?
    let voteCount: Int?
    let adult: Bool?
    let originCountry: [String]?
    let originalLanguage: String?
    let runtime: Int?
    let status: String?
    let productionCompanies: [ProductionCompany]?
    
    var recommendationReason: String? = nil
    
    // 🟢 修复 1：补回缺失的 isAdult 属性
    var isAdult: Bool { return adult ?? false }
    
    static func == (lhs: Movie, rhs: Movie) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    var posterURL: URL? { guard let p = posterPath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w500\(p)") }
    var thumbnailURL: URL? { guard let p = posterPath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w342\(p)") }
    var backdropURL: URL? { guard let p = backdropPath else { return nil }; return URL(string: "\(ImageDomainConfig.baseURL)w780\(p)") }
    
    var year: String {
        if !releaseDate.isEmpty { return String(releaseDate.prefix(4)) }
        return ""
    }
    
    var hasRating: Bool { (voteAverage ?? 0) > 0 && (voteCount ?? 0) > 0 }
    var scoreText: String { hasRating ? String(format: "%.1f", voteAverage!) : "暂无评分" }
    
    var durationString: String {
        guard let min = runtime, min > 0 else { return "" }
        let h = min / 60; let m = min % 60
        return h > 0 ? "\(h)\(NSLocalizedString("小时", comment: ""))\(m)\(NSLocalizedString("分", comment: ""))" : "\(m)\(NSLocalizedString("分钟", comment: ""))"
    }
    
    var genresString: String {
        guard let ids = genreIds else { return "" }
        return ids.compactMap { id in
            if let name = TMDBService.genreMap[id] { return NSLocalizedString(name, comment: "") }
            return nil
        }.prefix(2).joined(separator: " / ")
    }
    
    func smartTag(isOnboarding: Bool) -> String? {
        if isOnboarding { return genresString.isEmpty ? nil : genresString }
        guard let reason = recommendationReason, !reason.isEmpty else { return nil }
        
        if reason.contains("华语") || reason.contains("華語") || reason.contains("国产") || reason.contains("國產") || reason.contains("港产") {
            if originalLanguage != "zh" && originalLanguage != "cn" && originalLanguage != "yue" { return nil }
        }
        if reason.contains("日") && originalLanguage != "ja" { return nil }
        if reason.contains("韩") && originalLanguage != "ko" { return nil }
        if reason.contains("高分") || reason.contains("神作") { if (voteAverage ?? 0) < 7.0 { return nil } }
        if reason.contains("经典") || reason.contains("年代") { if let y = Int(year), y > 2010 { return nil } }
        return reason
    }
    
    var countryString: String {
        guard let code = originCountry?.first, !code.isEmpty else { return "" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }
    
    var languageString: String {
        guard let lang = originalLanguage, !lang.isEmpty else { return "" }
        if lang == "zh" || lang == "cn" { return NSLocalizedString("华语", comment: "") }
        let map = ["en":"英语", "ja":"日语", "ko":"韩语", "fr":"法语", "de":"德语", "it":"意大利语", "es":"西语", "ru":"俄语"]
        if let v = map[lang.lowercased()] { return NSLocalizedString(v, comment: "") }
        return Locale.current.localizedString(forIdentifier: lang) ?? lang
    }
    
    var infoString: String {
        var parts: [String] = []
        if !genresString.isEmpty { parts.append(genresString) }
        let langStr = languageString; let countryStr = countryString
        if originalLanguage == "zh" || originalLanguage == "cn" { if !langStr.isEmpty { parts.append(langStr) } }
        else {
            if !countryStr.isEmpty { parts.append(countryStr) }
            if !langStr.isEmpty { parts.append(langStr) }
        }
        return parts.joined(separator: " · ")
    }
    
    var onboardingInfoString: String {
        var parts: [String] = []
        if !year.isEmpty && year != "N/A" { parts.append(year) }
        if !countryString.isEmpty { parts.append(countryString) }
        return parts.joined(separator: " · ")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, status
        case posterPath = "poster_path", backdropPath = "backdrop_path", releaseDate = "release_date"
        case voteAverage = "vote_average", voteCount = "vote_count", genreIds = "genre_ids"
        case originalTitle = "original_title", productionCompanies = "production_companies"
        case originCountry = "origin_country", originalLanguage = "original_language", adult
    }
    
    // 🟢 修复 2：全能初始化方法
    // 这个 Init 包含了所有字段，并给可选字段设了 nil 默认值，
    // 这样 SavedMovie.toMovie 就可以调用它了，消除了 "Extra arguments" 报错
    init(id: Int,
         title: String,
         originalTitle: String? = nil,
         overview: String,
         posterPath: String? = nil,
         backdropPath: String? = nil,
         releaseDate: String = "",
         genreIds: [Int]? = [],
         voteAverage: Double? = nil,
         voteCount: Int? = nil,
         adult: Bool? = false,
         originCountry: [String]? = nil,
         originalLanguage: String? = nil,
         runtime: Int? = nil,
         status: String? = nil,
         productionCompanies: [ProductionCompany]? = nil,
         recommendationReason: String? = nil) {
        
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.genreIds = genreIds
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.adult = adult
        self.originCountry = originCountry
        self.originalLanguage = originalLanguage
        self.runtime = runtime
        self.status = status
        self.productionCompanies = productionCompanies
        self.recommendationReason = recommendationReason
    }
}

// MARK: - 适配 CloudKit 的 SwiftData 模型
@Model
class SavedMovie {
    @Attribute(.unique) var id: Int = 0
    var title: String = ""
    var posterPath: String?
    var overview: String = ""
    var releaseDate: String?
    var genreIds: [Int] = []
    var voteAverage: Double?
    var originCountry: [String] = []
    var originalLanguage: String?
    
    // 状态位
    var isLiked: Bool = false
    var isDisliked: Bool = false
    var isNeutral: Bool = false
    var isToWatch: Bool = false
    var isWatched: Bool = false
    var isIgnored: Bool = false
    
    var interactionDate: Date = Date()
    
    init() {}
    
    init(from movie: Movie) {
        self.id = movie.id
        self.title = movie.title
        self.posterPath = movie.posterPath
        self.overview = movie.overview
        self.releaseDate = movie.releaseDate
        self.genreIds = movie.genreIds ?? []
        self.voteAverage = movie.voteAverage
        self.originCountry = movie.originCountry ?? []
        self.originalLanguage = movie.originalLanguage
    }
    
    var toMovie: Movie {
        Movie(
            id: id,
            title: title,
            overview: overview,
            posterPath: posterPath,
            releaseDate: releaseDate ?? "",
            genreIds: genreIds,
            voteAverage: voteAverage,
            voteCount: 1000,
            adult: false,
            originCountry: originCountry,
            originalLanguage: originalLanguage,
            runtime: nil,
            productionCompanies: nil,
            recommendationReason: nil
        )
    }
}
