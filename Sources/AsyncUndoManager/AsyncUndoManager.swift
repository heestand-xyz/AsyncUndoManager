import Foundation

@MainActor
@Observable
public final class AsyncUndoManager {
    
    public var canUndo: Bool {
        !undos.isEmpty && !isUndoing && !isRedoing
    }
    public var canRedo: Bool {
        !redos.isEmpty && !isUndoing && !isRedoing
    }
    
    /// Undos; sorted by first is the most recent action and last is in the past.
    public private(set) var undos: [AsyncDo] = []
    /// Redos; sorted by first is the most recent action and last is in future.
    public private(set) var redos: [AsyncDo] = []
    
    /// Undo Groups; sorted by first is the most recent action and last is in the past.
    ///
    /// Each group has at least one undo.
    public var undoGroups: [AsyncDoGroup] {
        Self.group(dos: undos)
    }
    /// Redos Groups; sorted by first is the most recent action and last is in future.
    ///
    /// Each group has at least one redo.
    public var redoGroups: [AsyncDoGroup] {
        Self.group(dos: redos)
    }
    
    public private(set) var isUndoing: Bool = false
    public private(set) var isRedoing: Bool = false
    
    /// Levels of Undo
    ///
    /// `0` levels of undo indicates no limit. *(default)*
    ///
    /// When a limit is reached, the oldest undos will be discarded.
    public var levelsOfUndo: Int = 0
    
    public private(set) var isUndoRegistrationEnabled: Bool = true
    
    private var currentGroup: (id: UUID, name: String?)?
    
    public init() {}
}

extension AsyncUndoManager {
    /// Undos all changes up to and including the target group or do `id`.
    ///
    /// If the `id` is not found, no undos will happen.
    public func undoAll(to id: UUID) async {
        guard canUndo else { return }
        while undoGroups.contains(where: { $0.id == id || $0.dos.contains(where: { $0.id == id }) }) {
            await undo()
        }
    }
    
    public func undo() async {
        guard canUndo else { return }
        isUndoing = true
        let undo: AsyncDo = undos.removeFirst()
        if currentGroup == nil, let group: (id: UUID, name: String?) = undo.group {
            beginUndoGrouping(id: group.id, named: group.name)
        }
        await undo.action()
        isUndoing = false
        if canUndo, let groupID = undo.group?.id, undos.first?.group?.id == groupID {
            await self.undo()
        } else if currentGroup != nil {
            endUndoGrouping()
        }
    }
    
    /// Redos all changes up to and including the target group or do `id`.
    ///
    /// If the `id` is not found, no redos will happen.
    public func redoAll(to id: UUID) async {
        guard canRedo else { return }
        while redoGroups.contains(where: { $0.id == id || $0.dos.contains(where: { $0.id == id }) }) {
            await redo()
        }
    }
    
    public func redo() async {
        guard canRedo else { return }
        isRedoing = true
        let redo: AsyncDo = redos.removeFirst()
        if currentGroup == nil, let group: (id: UUID, name: String?) = redo.group {
            beginUndoGrouping(id: group.id, named: group.name)
        }
        await redo.action()
        isRedoing = false
        if canRedo, let groupID = redo.group?.id, redos.first?.group?.id == groupID {
            await self.redo()
        } else if currentGroup != nil {
            endUndoGrouping()
        }
    }
}

extension AsyncUndoManager {
    public func registerUndo(
        named name: String? = nil,
        _ action: @escaping @Sendable () async -> Void
    ) {
        guard isUndoRegistrationEnabled else { return }
        let `do` = AsyncDo(
            id: UUID(),
            group: currentGroup,
            name: name,
            action: action
        )
        if isUndoing {
            redos.insert(`do`, at: 0)
        } else {
            if !isRedoing {
                redos.removeAll()
            }
            undos.insert(`do`, at: 0)
            if levelsOfUndo > 0, undos.count > levelsOfUndo {
                undos.removeLast()
            }
        }
    }
}

extension AsyncUndoManager {
    public func beginUndoGrouping(
        named name: String? = nil
    ) {
        beginUndoGrouping(id: UUID(), named: name)
    }
    
    private func beginUndoGrouping(
        id: UUID,
        named name: String?
    ) {
        currentGroup = (id, name)
    }
    
    public func endUndoGrouping() {
        currentGroup = nil
    }
    
    private static func group(dos: [AsyncDo]) -> [AsyncDoGroup] {
        var grouped: [AsyncDoGroup] = []
        for `do` in dos {
            if let groupID = `do`.group?.id, grouped.last?.dos.last?.group?.id == groupID {
                grouped[grouped.count - 1].dos.append(`do`)
            } else {
                let group = AsyncDoGroup(
                    id: `do`.group?.id ?? `do`.id,
                    name: `do`.group?.name ?? `do`.name,
                    dos: [`do`]
                )
                grouped.append(group)
            }
        }
        return grouped
    }
}

extension AsyncUndoManager {
    public func enableUndoRegistration() {
        isUndoRegistrationEnabled = true
    }
    
    public func disableUndoRegistration() {
        isUndoRegistrationEnabled = false
    }
}

extension AsyncUndoManager {
    public func removeAllActions() {
        undos = []
        redos = []
    }
}
