//
//  TipStore.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/15.
//

import StoreKit
import SwiftUI

// 🟢 这里定义你在 App Store Connect 里创建的商品 ID
// 请确保去 App Store Connect -> In-App Purchases -> Create Consumable
// ID 建议命名为: com.yourname.kinotaste.tip.small 等
enum TipID: String, CaseIterable {
    case small  = "com.kinotaste.tip.small"  // e.g. $1 / ¥6
    case medium = "com.kinotaste.tip.medium" // e.g. $3 / ¥18
    case large  = "com.kinotaste.tip.large"  // e.g. $5 / ¥30
}

@MainActor
class TipStore: ObservableObject {
    static let shared = TipStore()
    
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseState: PurchaseState = .idle
    
    enum PurchaseState {
        case idle
        case purchasing
        case success
        case failed(String)
    }
    
    init() {
        // 初始化时开始监听交易更新 (StoreKit 2)
        Task { await listenForTransactions() }
    }
    
    func requestProducts() async {
        self.isLoading = true
        do {
            let productIds = TipID.allCases.map { $0.rawValue }
            let fetchedProducts = try await Product.products(for: productIds)
            
            // 按价格排序
            self.products = fetchedProducts.sorted(by: { $0.price < $1.price })
            self.isLoading = false
        } catch {
            print("❌ 获取商品失败: \(error)")
            self.isLoading = false
        }
    }
    
    func purchase(_ product: Product) async {
        self.purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 验证交易签名
                switch verification {
                case .verified(let transaction):
                    print("✅ 购买成功: \(transaction.productID)")
                    self.purchaseState = .success
                    await transaction.finish() // 必须完成交易
                    
                    // 2秒后重置状态
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.purchaseState = .idle
                    
                case .unverified(_, let error):
                    print("❌ 交易未验证: \(error)")
                    self.purchaseState = .failed("验证失败")
                }
            case .userCancelled:
                print("用户取消")
                self.purchaseState = .idle
            case .pending:
                print("交易挂起")
                self.purchaseState = .idle
            @unknown default:
                self.purchaseState = .idle
            }
        } catch {
            print("❌ 购买出错: \(error)")
            self.purchaseState = .failed(error.localizedDescription)
        }
    }
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await transaction.finish()
                print("♻️ 处理后台交易: \(transaction.productID)")
            case .unverified:
                break
            }
        }
    }
}
