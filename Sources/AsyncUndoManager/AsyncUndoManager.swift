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
    
    private var groupMetadataList: [AsyncDoGroupMetadata] = []
    
    private var currentGroupMetadata: AsyncDoGroupMetadata? {
        groupMetadataList.first
    }
    
    public var currentGroupID: UUID? {
        currentGroupMetadata?.id
    }
    
    public var currentGroupName: String? {
        currentGroupMetadata?.name
    }
    
    public var currentGroupObject: Sendable? {
        currentGroupMetadata?.object
    }
    
    /// The number of nested undo groups.
    ///
    /// `0` is default and indicates no groups are active.
    public var groupingLevel: Int {
        groupMetadataList.count
    }
    
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
        if currentGroupMetadata == nil, let groupMetadata: AsyncDoGroupMetadata = undo.groupMetadata {
            beginUndoGrouping(metadata: groupMetadata)
        }
        await undo.action()
        isUndoing = false
        if canUndo, let groupID = undo.groupMetadata?.id, undos.first?.groupMetadata?.id == groupID {
            await self.undo()
        } else if currentGroupMetadata != nil {
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
        if currentGroupMetadata == nil, let groupMetadata: AsyncDoGroupMetadata = redo.groupMetadata {
            beginUndoGrouping(metadata: groupMetadata)
        }
        await redo.action()
        isRedoing = false
        if canRedo, let groupID = redo.groupMetadata?.id, redos.first?.groupMetadata?.id == groupID {
            await self.redo()
        } else if currentGroupMetadata != nil {
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
            groupMetadata: currentGroupMetadata,
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
    /// Begin a grouping of dos.
    /// - Parameters:
    ///   - name: Attach a name to your group. (optional)
    ///   - object: Attach an object to your group. (optional)
    public func beginUndoGrouping(
        named name: String? = nil,
        object: Sendable? = nil
    ) {
        let metadata = AsyncDoGroupMetadata(id: UUID(), name: name, object: object)
        beginUndoGrouping(metadata: metadata)
    }
    
    private func beginUndoGrouping(
        metadata: AsyncDoGroupMetadata
    ) {
        groupMetadataList.append(metadata)
    }
    
    public func endUndoGrouping() {
        if groupMetadataList.isEmpty { return }
        groupMetadataList.removeLast()
    }
    
    private static func group(dos: [AsyncDo]) -> [AsyncDoGroup] {
        var grouped: [AsyncDoGroup] = []
        for `do` in dos {
            if let groupID = `do`.groupMetadata?.id, grouped.last?.dos.last?.groupMetadata?.id == groupID {
                grouped[grouped.count - 1].dos.append(`do`)
            } else {
                let metadata: AsyncDoGroupMetadata = if let metadata = `do`.groupMetadata {
                    metadata
                } else {
                    AsyncDoGroupMetadata(id: `do`.id, name: `do`.name, object: nil)
                }
                let group = AsyncDoGroup(
                    metadata: metadata,
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
