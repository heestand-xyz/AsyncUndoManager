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
    
    /// Grouped Undos; sorted by first is the most recent action and last is in the past.
    ///
    /// Each group has at least one undo.
    public var groupedUndos: [AsyncDoGroup] {
        Self.group(dos: undos)
    }
    /// Grouped Redos; sorted by first is the most recent action and last is in future.
    ///
    /// Each group has at least one redo.
    public var groupedRedos: [AsyncDoGroup] {
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
    public func undo() async {
        guard !isUndoing, !isRedoing else { return }
        guard canUndo else { return }
        isUndoing = true
        let undo: AsyncDo = undos.removeFirst()
        if let group: (id: UUID, name: String?) = undo.group {
            beginUndoGrouping(id: group.id, named: group.name)
        }
        await undo.action()
        if undo.group != nil {
            endUndoGrouping()
        }
        isUndoing = false
        if canUndo, let groupID = undo.group?.id, undos.first?.group?.id == groupID {
            await self.undo()
        }
    }
    
    public func redo() async {
        guard !isUndoing, !isRedoing else { return }
        guard canRedo else { return }
        isRedoing = true
        let redo: AsyncDo = redos.removeFirst()
        if let group: (id: UUID, name: String?) = redo.group {
            beginUndoGrouping(id: group.id, named: group.name)
        }
        await redo.action()
        if redo.group != nil {
            endUndoGrouping()
        }
        isRedoing = false
        if canRedo, let groupID = redo.group?.id, redos.first?.group?.id == groupID {
            await self.redo()
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
            undos.insert(`do`, at: 0)
            if !isRedoing {
                redos.removeAll()
            }
            if levelsOfUndo > 0, undos.count > levelsOfUndo {
                undos.removeLast()
            }
        }
    }
}

extension AsyncUndoManager {
    public func beginUndoGrouping(
        id: UUID = UUID(),
        named name: String? = nil
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
