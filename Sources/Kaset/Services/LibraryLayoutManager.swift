import Foundation
import Observation

// MARK: - LibraryLayoutManager

/// Local-only Library customization: a manual tile order and hidden tiles.
/// YouTube Music has no API for either, so both live in UserDefaults and never touch the account.
@MainActor
@Observable
final class LibraryLayoutManager {
    static let shared = LibraryLayoutManager()

    private enum Keys {
        static let order = "library.layout.order"
        static let hidden = "library.layout.hidden"
    }

    private(set) var order: [String]
    private(set) var hidden: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.order = defaults.stringArray(forKey: Keys.order) ?? []
        self.hidden = Set(defaults.stringArray(forKey: Keys.hidden) ?? [])
    }

    func isHidden(_ id: String) -> Bool {
        self.hidden.contains(id)
    }

    func setHidden(_ isHidden: Bool, id: String) {
        if isHidden {
            self.hidden.insert(id)
        } else {
            self.hidden.remove(id)
        }
        self.defaults.set(self.hidden.sorted(), forKey: Keys.hidden)
    }

    /// Sorts tiles by the saved order. Tiles never placed manually (e.g. newly saved ones)
    /// keep their API order and come first, so new additions stay visible at the top.
    func sorted<Item>(_ items: [Item], id: (Item) -> String) -> [Item] {
        let positions = Dictionary(self.order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let unplaced = items.filter { positions[id($0)] == nil }
        let placed = items
            .filter { positions[id($0)] != nil }
            .sorted { (positions[id($0)] ?? 0) < (positions[id($1)] ?? 0) }
        return unplaced + placed
    }

    /// Moves `sourceId` to the slot of `targetId` within `currentIds` (the full, already sorted
    /// tile list) and saves the result as the new order.
    func move(_ sourceId: String, onto targetId: String, in currentIds: [String]) {
        guard sourceId != targetId,
              let sourceIndex = currentIds.firstIndex(of: sourceId),
              let targetIndex = currentIds.firstIndex(of: targetId)
        else { return }

        var ids = currentIds
        ids.remove(at: sourceIndex)
        ids.insert(sourceId, at: targetIndex)
        self.order = ids
        self.defaults.set(ids, forKey: Keys.order)
    }

    func resetOrder() {
        self.order = []
        self.defaults.removeObject(forKey: Keys.order)
    }
}
