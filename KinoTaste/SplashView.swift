//
//  SplashView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/8.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Image("LaunchImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("今天看什么")
                    .retroFont(size: 38, bold: true) // ✅
                    .foregroundColor(.black.opacity(0.9))
                    .tracking(2)
                    .shadow(color: .white.opacity(0.5), radius: 0, x: 1, y: 1)
                
                Text("发现你的下一部电影")
                    .retroFont(size: 14) // ✅
                    .foregroundColor(.black.opacity(0.7))
                    .tracking(1)
            }
            .padding(.horizontal)
            .offset(y: -28)
            
            RetroFilmOverlay(vignetteIntensity: 0.6, grainIntensity: 0.15)
        }
    }
}
