import Foundation
import Testing
import AsyncUndoManager

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct UndoAttemptTests {

    @Test("AsyncUndoManager: Failed undo retains the same entry for retry", arguments: [false, true])
    func failedUndo(all: Bool) async throws {
        let fixture: UndoAttemptFixture = UndoAttemptFixture()
        _ = await fixture.setValue(1)
        let id: UUID = try #require(fixture.manager.undoGroups.first).id
        fixture.isAvailable = false
        if all { await fixture.manager.undoAll(to: id) }
        else { await fixture.manager.undo() }
        #expect(fixture.value == 1)
        #expect(fixture.manager.undoGroups.first?.id == id)
        #expect(fixture.manager.redoGroups.isEmpty)
        #expect(fixture.manager.canUndo)
        #expect(!fixture.manager.isUndoing)
        fixture.isAvailable = true
        await fixture.manager.undo()
        #expect(fixture.value == 0)
        #expect(fixture.manager.canRedo)
    }

    @Test("AsyncUndoManager: Failed redo retains the same entry for retry", arguments: [false, true])
    func failedRedo(all: Bool) async throws {
        let fixture: UndoAttemptFixture = UndoAttemptFixture()
        _ = await fixture.setValue(1)
        await fixture.manager.undo()
        let id: UUID = try #require(fixture.manager.redoGroups.first).id
        fixture.isAvailable = false
        if all { await fixture.manager.redoAll(to: id) }
        else { await fixture.manager.redo() }
        #expect(fixture.value == 0)
        #expect(fixture.manager.redoGroups.first?.id == id)
        #expect(fixture.manager.undoGroups.isEmpty)
        #expect(fixture.manager.canRedo)
        #expect(!fixture.manager.isRedoing)
        fixture.isAvailable = true
        await fixture.manager.redo()
        #expect(fixture.value == 1)
        #expect(fixture.manager.canUndo)
    }
}

@MainActor
private final class UndoAttemptFixture {
    let manager: AsyncUndoManager = AsyncUndoManager()
    var value: Int = 0
    var isAvailable: Bool = true

    func setValue(_ value: Int) async -> Bool {
        guard isAvailable else { return false }
        let oldValue: Int = self.value
        self.value = value
        await manager.registerUndoAttempt(named: "Set value") { [self] in
            await setValue(oldValue)
        }
        return true
    }
}
