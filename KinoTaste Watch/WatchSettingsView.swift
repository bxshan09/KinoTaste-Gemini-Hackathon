//
//  WatchSettingsView.swift
//  KinoTaste Watch App
//
//  Created by Boxiang Shan on 2026/1/10.
//

import SwiftUI
import SDWebImageSwiftUI

struct WatchSettingsView: View {
    // 🟢 状态变量：先确认，再提示成功
    @State private var showClearConfirmation = false
    @State private var showClearSuccess = false
    
    @State private var showResetAlert = false
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        // 1. 触发确认弹窗
                        showClearConfirmation = true
                    } label: {
                        Label("清除图片缓存", systemImage: "trash")
                    }
                    
                    Button {
                        viewModel.requestReview()
                    } label: {
                        Label("给个好评", systemImage: "star.bubble")
                    }
                } header: {
                    Text("存储与评价")
                }
                
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("重置口味数据", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KinoTaste for Watch")
                            .font(.headline)
                        
                        // 🟢 修复：拆分文本，确保 "Version" 能匹配到 Strings 文件里的 Key
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey("Version")) // 这里会显示 "版本"
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 4)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "database")
                            Text(LocalizedStringKey("Data provided by TMDB"))
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("设置")
            // 🟢 1. 确认弹窗
            .alert("确认清除？", isPresented: $showClearConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确定", role: .destructive) {
                    SDImageCache.shared.clearMemory()
                    SDImageCache.shared.clearDisk()
                    // 延迟显示成功提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showClearSuccess = true
                    }
                }
            } message: {
                Text("将删除所有已下载的海报图片。")
            }
            // 🟢 2. 成功提示
            .alert("已清除", isPresented: $showClearSuccess) {
                Button("好") { }
            } message: {
                Text("空间已释放。")
            }
            // 重置弹窗
            .alert("确定重置？", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("确定", role: .destructive) {
                    viewModel.resetApp()
                }
            } message: {
                Text("所有数据将被清空且无法恢复。")
            }
        }
    }
}
