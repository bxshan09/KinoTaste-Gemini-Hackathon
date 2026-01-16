//
//  ErrorView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/4.
//
import SwiftUI

struct ErrorView: View {
    let errorText: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("哎呀，出错了")
                .retroFont(size: 22, bold: true) // ✅
            
            Text(LocalizedStringKey(errorText))
                .retroFont(size: 14) // ✅
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Text("重试")
                    .retroFont(size: 16, bold: true) // ✅
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(Color.black)
                    .cornerRadius(25)
            }
        }
        .padding()
        .background(Color.white)
    }
}
