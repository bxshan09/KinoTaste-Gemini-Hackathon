// ==========================================
// FILE PATH: ./KinoTaste Watch/WatchMovieCard.swift
// ==========================================

import SwiftUI
import SDWebImageSwiftUI

struct WatchMovieCard: View {
    let movie: Movie
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 1. 海报
            WebImage(url: movie.posterURL)
                .resizable()
                .indicator(.activity)
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipped()
            
            // 2. 渐变遮罩
            LinearGradient(
                colors: [.clear, .black.opacity(0.1), .black.opacity(0.8), .black],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // 3. 信息文字
            VStack(alignment: .leading, spacing: 1) {
                Text(movie.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black, radius: 2)
                
                HStack(spacing: 4) {
                    // 评分
                    if let score = movie.voteAverage, score > 0 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.yellow)
                        
                        Text("·")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // 年份
                    Text(movie.year)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // 地区/语言 (🟢 核心修复部分)
                    if let (isKey, text) = getLanguageDisplay() {
                        Text("·")
                            .foregroundColor(.white.opacity(0.5))
                        
                        if isKey {
                            // 🟢 情况A：如果是手动映射的 Key (如 "英语")，强制用 LocalizedStringKey 包裹
                            // 这样系统才会去 strings 文件里查到 "英語"
                            Text(LocalizedStringKey(text))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            // 🟢 情况B：如果是系统 Locale 返回的 (如 "Español")，直接显示
                            Text(text)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(8)
            .padding(.bottom, 3)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
    
    // 🟢 辅助函数：返回 (是否为Key, 文本内容)
    private func getLanguageDisplay() -> (Bool, String)? {
        // 1. 优先显示地区 (如 US, CN) -> 系统自动翻译
        if let countryCode = movie.originCountry?.first, !countryCode.isEmpty {
            let countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
            return (false, countryName)
        }
        
        // 2. 显示语言
        if let langCode = movie.originalLanguage, !langCode.isEmpty {
            // 手动映射表 (对应 Localizable.strings 中的 Keys)
            let manualMap: [String: String] = [
                "en": "英语", "ja": "日语", "ko": "韩语", "zh": "华语", "cn": "华语",
                "fr": "法语", "de": "德语", "it": "意大利语", "es": "西语",
                "ru": "俄语", "hi": "印地语", "th": "泰语",
                // 👇 新增补充
                                "pt": "葡语", "da": "丹麦语", "sv": "瑞典语",
                                "fa": "波斯语", "nl": "荷兰语", "pl": "波兰语"
            ]
            
            // 如果在映射表中，返回 (true, Key)
            if let keyName = manualMap[langCode.lowercased()] {
                return (true, keyName)
            }
            
            // 否则使用系统翻译，返回 (false, String)
            let sysLang = Locale.current.localizedString(forIdentifier: langCode) ?? langCode
            return (false, sysLang)
        }
        return nil
    }
}
