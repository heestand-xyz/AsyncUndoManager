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
    public private(set) var undoGroups: [AsyncDoGroup] = []
    /// Redos Groups; sorted by first is the most recent action and last is in future.
    ///
    /// Each group has at least one redo.
    public private(set) var redoGroups: [AsyncDoGroup] = []
    
    public private(set) var isUndoing: Bool = false
    public private(set) var isRedoing: Bool = false
    
    /// Levels of Undo
    ///
    /// `0` levels of undo indicates no limit. *(default)*
    ///
    /// When a limit is reached, the oldest undos will be discarded.
    @ObservationIgnored
    public var levelsOfUndo: Int = 0
    
    @ObservationIgnored
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
    @concurrent
    public func undoAll(to id: UUID) async {
        guard await canUndo else { return }
        while await undoGroups.contains(where: { $0.id == id || $0.dos.contains(where: { $0.id == id }) }) {
            let previousID: UUID? = await undos.first?.id
            await undo(force: true)
            if await undos.first?.id == previousID { break }
        }
    }
    
    public func undo() async {
        await undo(force: false)
    }
    
    private func undo(force: Bool) async {
        guard force ? !undos.isEmpty : canUndo else { return }
        isUndoing = true
        let undo: AsyncDo = undos.first!
        await editUndos { undos in
            undos.removeFirst()
        }
        if currentGroupMetadata == nil, let groupMetadata: AsyncDoGroupMetadata = undo.groupMetadata {
            beginUndoGrouping(metadata: groupMetadata)
        }
        let succeeded: Bool = await undo.action()
        isUndoing = false
        guard succeeded else {
            await editUndos { $0.insert(undo, at: 0) }
            if currentGroupMetadata != nil { endUndoGrouping() }
            return
        }
        if force ? !undos.isEmpty : canUndo, let groupID = undo.groupMetadata?.id, undos.first?.groupMetadata?.id == groupID {
            await self.undo(force: force)
        } else if currentGroupMetadata != nil {
            endUndoGrouping()
        }
    }
    
    /// Redos all changes up to and including the target group or do `id`.
    ///
    /// If the `id` is not found, no redos will happen.
    @concurrent
    public func redoAll(to id: UUID) async {
        guard await canRedo else { return }
        while await redoGroups.contains(where: { $0.id == id || $0.dos.contains(where: { $0.id == id }) }) {
            let previousID: UUID? = await redos.first?.id
            await redo(force: true)
            if await redos.first?.id == previousID { break }
        }
    }
    
    public func redo() async {
        await redo(force: false)
    }
    
    private func redo(force: Bool) async {
        guard force ? !redos.isEmpty : canRedo else { return }
        isRedoing = true
        let redo: AsyncDo = redos.first!
        await editRedos { redos in
            redos.removeFirst()
        }
        if currentGroupMetadata == nil, let groupMetadata: AsyncDoGroupMetadata = redo.groupMetadata {
            beginUndoGrouping(metadata: groupMetadata)
        }
        let succeeded: Bool = await redo.action()
        isRedoing = false
        guard succeeded else {
            await editRedos { $0.insert(redo, at: 0) }
            if currentGroupMetadata != nil { endUndoGrouping() }
            return
        }
        if force ? !redos.isEmpty : canRedo, let groupID = redo.groupMetadata?.id, redos.first?.groupMetadata?.id == groupID {
            await self.redo(force: force)
        } else if currentGroupMetadata != nil {
            endUndoGrouping()
        }
    }
}

extension AsyncUndoManager {
    public func registerUndo(
        named name: String? = nil,
        _ action: @escaping @Sendable () async -> Void
    ) async {
        await registerUndoAttempt(named: name) {
            await action()
            return true
        }
    }

    /// A failed attempt keeps its entry for retry. It must leave the graph unchanged
    /// and must not register an inverse before returning false.
    public func registerUndoAttempt(
        named name: String? = nil,
        _ action: @escaping @Sendable () async -> Bool
    ) async {
        guard isUndoRegistrationEnabled else { return }
        let `do` = AsyncDo(
            id: UUID(),
            groupMetadata: currentGroupMetadata,
            name: name,
            action: action
        )
        if isUndoing {
            await editRedos { redos in
                redos.insert(`do`, at: 0)
            }
        } else {
            if !isRedoing {
                await editRedos { redos in
                    redos.removeAll()
                }
            }
            await editUndos { undos in
                undos.insert(`do`, at: 0)
            }
            if levelsOfUndo > 0, undos.count > levelsOfUndo {
                await editUndos { undos in
                    undos.removeLast()
                }
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
    
    @concurrent
    private static func group(dos: [AsyncDo]) async -> [AsyncDoGroup] {
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
    public func removeAllActions() async {
        await editUndos { undos in
            undos = []
        }
        await editRedos { redos in
            redos = []
        }
    }
}

extension AsyncUndoManager {
    private func editUndos(_ edit: (inout [AsyncDo]) -> Void) async {
        edit(&undos)
        undoGroups = await Self.group(dos: undos)
    }
    
    private func editRedos(_ edit: (inout [AsyncDo]) -> Void) async {
        edit(&redos)
        redoGroups = await Self.group(dos: redos)
    }
}
