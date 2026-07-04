//
//  Shop.swift
//  TunnelDrop
//
//  Coin pack IAPs (StoreKit 2), bird skins purchasable with coins,
//  and the Remove Ads product.
//

import SwiftUI
import StoreKit

struct Skin: Identifiable {
    let id: String
    let name: String
    let price: Int
    let tint: UIColor?

    var previewColor: Color {
        guard let tint else { return .white }
        return Color(uiColor: tint)
    }

    static let all: [Skin] = [
        Skin(id: "classic", name: "Classic", price: 0, tint: nil),
        Skin(id: "astro", name: "Astro", price: 300, tint: UIColor(red: 0.5, green: 0.6, blue: 1.0, alpha: 1)),
        Skin(id: "ninja", name: "Ninja", price: 500, tint: UIColor(white: 0.3, alpha: 1)),
    ]

    static func equipped() -> Skin {
        let id = UserDefaults.standard.string(forKey: "equippedSkin") ?? "classic"
        return all.first { $0.id == id } ?? all[0]
    }
}

@MainActor
final class ShopStore: ObservableObject {
    @Published var products: [String: Product] = [:]
    @Published var purchaseError: String?

    static let coinPacks: [(id: String, coins: Int, bonus: String?, fallbackPrice: String)] = [
        ("com.jerrycox.TunnelDrop.coins100", 100, nil, "$0.99"),
        ("com.jerrycox.TunnelDrop.coins550", 550, "+10% BONUS", "$3.99"),
        ("com.jerrycox.TunnelDrop.coins1500", 1500, "+25% BONUS", "$9.99"),
    ]
    static let removeAdsID = "com.jerrycox.TunnelDrop.removeads"

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task { await loadProducts() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let ids = Self.coinPacks.map(\.id) + [Self.removeAdsID]
            let loaded = try await Product.products(for: ids)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            purchaseError = "Store unavailable: \(error.localizedDescription)"
        }
    }

    func purchase(_ productID: String) async {
        guard let product = products[productID] else { return }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                grant(transaction)
                await transaction.finish()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func listenForTransactions() async {
        for await update in StoreKit.Transaction.updates {
            if case .verified(let transaction) = update {
                grant(transaction)
                await transaction.finish()
            }
        }
    }

    private func grant(_ transaction: StoreKit.Transaction) {
        let defaults = UserDefaults.standard
        if let pack = Self.coinPacks.first(where: { $0.id == transaction.productID }) {
            defaults.set(defaults.integer(forKey: "coinBalance") + pack.coins, forKey: "coinBalance")
        } else if transaction.productID == Self.removeAdsID {
            defaults.set(true, forKey: "removeAds")
        }
    }
}

struct ShopView: View {
    @StateObject private var store = ShopStore()
    @AppStorage("coinBalance") private var coinBalance = 0
    @AppStorage("ownedSkins") private var ownedSkinsRaw = "classic"
    @AppStorage("equippedSkin") private var equippedSkin = "classic"
    @AppStorage("removeAds") private var removeAds = false

    private var ownedSkins: Set<String> {
        Set(ownedSkinsRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Shop")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("🪙 \(coinBalance)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.pill, in: Capsule())
                }

                sectionHeader("COIN PACKS")
                HStack(spacing: 10) {
                    ForEach(ShopStore.coinPacks, id: \.id) { pack in
                        coinPackTile(pack)
                    }
                }

                sectionHeader("BIRD SKINS")
                HStack(spacing: 10) {
                    ForEach(Skin.all) { skin in
                        skinTile(skin)
                    }
                }

                removeAdsBanner
                    .padding(.top, 8)

                Button("Restore Purchases") {
                    Task { try? await AppStore.sync() }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

                if let error = store.purchaseError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(22)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.secondary)
            .kerning(2)
    }

    private func coinPackTile(_ pack: (id: String, coins: Int, bonus: String?, fallbackPrice: String)) -> some View {
        let product = store.products[pack.id]
        let isBestValue = pack.coins == 1500

        return VStack(spacing: 8) {
            Text("🪙")
                .font(.system(size: 34))
            Text("\(pack.coins)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(pack.bonus ?? " ")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gold)

            Button {
                Task { await store.purchase(pack.id) }
            } label: {
                Text(product?.displayPrice ?? pack.fallbackPrice)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.green, in: Capsule())
            }
            .disabled(product == nil)
            .opacity(product == nil ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isBestValue ? Theme.gold : .clear, lineWidth: 2)
        )
        .overlay(alignment: .top) {
            if isBestValue {
                Text("BEST VALUE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.gold, in: Capsule())
                    .offset(y: -10)
            }
        }
    }

    private func skinTile(_ skin: Skin) -> some View {
        let owned = ownedSkins.contains(skin.id)
        let isEquipped = equippedSkin == skin.id
        let canAfford = coinBalance >= skin.price

        return VStack(spacing: 8) {
            Image("player-1")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .colorMultiply(skin.previewColor)
                .padding(12)
                .background(Theme.pill, in: Circle())

            Text(skin.name)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Button {
                if isEquipped { return }
                if owned {
                    equippedSkin = skin.id
                } else if canAfford {
                    coinBalance -= skin.price
                    ownedSkinsRaw += ",\(skin.id)"
                    equippedSkin = skin.id
                }
            } label: {
                Group {
                    if isEquipped {
                        Text("EQUIPPED")
                    } else if owned {
                        Text("EQUIP")
                    } else {
                        Text("🪙 \(skin.price)")
                    }
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isEquipped ? Theme.orange.opacity(0.35) : (owned || canAfford ? Theme.orange : Theme.pill),
                    in: Capsule()
                )
            }
            .disabled(!owned && !canAfford && !isEquipped)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isEquipped ? Theme.orange : .clear, lineWidth: 2)
        )
    }

    private var removeAdsBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "nosign")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Remove Ads")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(removeAds ? "Purchased — thank you!" : "No interruptions, ever")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if removeAds {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.green)
            } else {
                Button {
                    Task { await store.purchase(ShopStore.removeAdsID) }
                } label: {
                    Text(store.products[ShopStore.removeAdsID]?.displayPrice ?? "$2.99")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.green, in: Capsule())
                }
                .disabled(store.products[ShopStore.removeAdsID] == nil)
                .opacity(store.products[ShopStore.removeAdsID] == nil ? 0.5 : 1)
            }
        }
        .padding(16)
        .background(Color(red: 0.16, green: 0.13, blue: 0.30), in: RoundedRectangle(cornerRadius: 20))
    }
}
