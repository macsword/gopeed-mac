import Foundation

enum SelectionModifier: Equatable {
    case replace
    case toggle
    case range
}

struct TaskSelection: Equatable {
    private(set) var ids: Set<String> = []
    private(set) var primary: String?
    private(set) var anchor: String?

    var count: Int { ids.count }
    var isMultiple: Bool { ids.count > 1 }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    func areAllSelected(_ visible: [String]) -> Bool {
        !visible.isEmpty && visible.allSatisfy(ids.contains)
    }

    mutating func handleClick(_ id: String, visible: [String], modifier: SelectionModifier) {
        switch modifier {
        case .replace:
            selectOnly(id)
        case .toggle:
            toggle(id, visible: visible)
        case .range:
            selectRange(to: id, visible: visible)
        }
    }

    mutating func selectOnly(_ id: String) {
        ids = [id]
        primary = id
        anchor = id
    }

    mutating func toggle(_ id: String, visible: [String]) {
        if ids.contains(id) {
            guard ids.count > 1 else { return }
            ids.remove(id)
            if primary == id {
                primary = visible.first { ids.contains($0) }
            }
            if anchor == id {
                anchor = primary
            }
        } else {
            ids.insert(id)
            primary = id
            anchor = id
        }
    }

    mutating func selectRange(to id: String, visible: [String]) {
        guard let startID = anchor ?? primary,
              let start = visible.firstIndex(of: startID),
              let end = visible.firstIndex(of: id)
        else {
            selectOnly(id)
            return
        }
        let lo = min(start, end)
        let hi = max(start, end)
        ids = Set(visible[lo...hi])
        primary = id
    }

    mutating func selectAll(_ visible: [String]) {
        ids = Set(visible)
        if let primary, ids.contains(primary) {
            if let anchor, ids.contains(anchor) { return }
            anchor = primary
            return
        }
        primary = visible.first
        anchor = primary
    }

    mutating func collapse() {
        if let primary {
            selectOnly(primary)
        }
    }

    mutating func remove(_ gone: Set<String>) {
        ids.subtract(gone)
        if let current = primary, gone.contains(current) {
            primary = nil
        }
        if let current = anchor, gone.contains(current) {
            anchor = primary
        }
    }

    mutating func reconcile(visible: [String]) {
        let visibleSet = Set(visible)
        ids = ids.intersection(visibleSet)
        if let current = primary, ids.contains(current) {
            if let currentAnchor = anchor, ids.contains(currentAnchor) { return }
            anchor = current
            return
        }
        let next = visible.first { ids.contains($0) } ?? visible.first
        primary = next
        anchor = next
        if let next {
            ids.insert(next)
        }
    }
}
