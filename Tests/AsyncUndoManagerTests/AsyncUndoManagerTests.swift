import Testing
import AsyncUndoManager

actor ValueActor<T>: Sendable {
    var value: T
    init(value: T) {
        self.value = value
    }
    func update(to value: T) {
        self.value = value
    }
}

@Test @MainActor func testUndo() async throws {
    let undoManager = AsyncUndoManager()
    
    let actor = ValueActor(value: 0)

    @Sendable func updateValue(to newValue: Int) async {
        let oldValue = await actor.value
        await actor.update(to: newValue)
        await undoManager.registerUndo {
            await updateValue(to: oldValue)
        }
    }

    await updateValue(to: 1)

    await #expect(actor.value == 1)

    await undoManager.undo()

    await #expect(actor.value == 0)
    #expect(undoManager.canUndo == false)
    #expect(undoManager.canRedo == true)
}

@Test @MainActor func testRedo() async throws {
    let undoManager = AsyncUndoManager()
    
    let actor = ValueActor(value: 0)

    @Sendable func updateValue(to newValue: Int) async {
        let oldValue = await actor.value
        await actor.update(to: newValue)
        await undoManager.registerUndo {
            await updateValue(to: oldValue)
        }
    }

    await updateValue(to: 1)
    await #expect(actor.value == 1)

    await updateValue(to: 2)
    await #expect(actor.value == 2)

    await undoManager.undo()
    await #expect(actor.value == 1)

    await undoManager.redo()
    await #expect(actor.value == 2)

    #expect(undoManager.canUndo == true)
    #expect(undoManager.canRedo == false)
}

@Test @MainActor func testLevelsOfUndo() async throws {
    let undoManager = AsyncUndoManager()
    await MainActor.run {
        undoManager.levelsOfUndo = 2
    }
    
    let actor = ValueActor(value: 0)

    @Sendable func updateValue(to newValue: Int) async {
        let oldValue = await actor.value
        await actor.update(to: newValue)
        await undoManager.registerUndo {
            await updateValue(to: oldValue)
        }
    }

    await updateValue(to: 1)
    await updateValue(to: 2)
    await updateValue(to: 3)

    #expect(undoManager.undos.count == 2)

    await undoManager.undo()
    await #expect(actor.value == 2)

    await undoManager.undo()
    await #expect(actor.value == 1)

    #expect(undoManager.canUndo == false)
}

@Test @MainActor func testUndoGrouping() async throws {
    let undoManager = AsyncUndoManager()
    
    let actor = ValueActor(value: 0)

    @Sendable func updateValue(to newValue: Int) async {
        let oldValue = await actor.value
        await actor.update(to: newValue)
        await undoManager.registerUndo {
            await updateValue(to: oldValue)
        }
    }

    undoManager.beginUndoGrouping()
    await updateValue(to: 1)
    await updateValue(to: 2)
    undoManager.endUndoGrouping()
    await updateValue(to: 3)

    #expect(undoManager.undoGroups.count == 2)
    #expect(undoManager.undoGroups.allSatisfy({ !$0.dos.isEmpty }))

    await undoManager.undo()
    await #expect(actor.value == 2)

    await undoManager.undo()
    await #expect(actor.value == 0)

    #expect(undoManager.canUndo == false)
    
    #expect(undoManager.redoGroups.count == 2)
    #expect(undoManager.redoGroups.allSatisfy({ !$0.dos.isEmpty }))
    
    await undoManager.redo()
    await #expect(actor.value == 2)

    #expect(undoManager.canUndo)
    #expect(undoManager.canRedo)
    
    #expect(undoManager.undoGroups.count == 1)
    #expect(undoManager.redoGroups.count == 1)
    #expect(undoManager.undoGroups.allSatisfy({ !$0.dos.isEmpty }))
    #expect(undoManager.redoGroups.allSatisfy({ !$0.dos.isEmpty }))
}

@Test @MainActor func testNestedUndoGrouping() async throws {
    let undoManager = AsyncUndoManager()
    
    let actor = ValueActor(value: 0)

    @Sendable func updateValue(to newValue: Int) async {
        let oldValue = await actor.value
        await actor.update(to: newValue)
        await undoManager.registerUndo {
            await updateValue(to: oldValue)
        }
    }

    #expect(undoManager.groupingLevel == 0)
    undoManager.beginUndoGrouping()
    #expect(undoManager.groupingLevel == 1)
    await updateValue(to: 1)
    undoManager.beginUndoGrouping()
    #expect(undoManager.groupingLevel == 2)
    await updateValue(to: 2)
    await updateValue(to: 3)
    undoManager.endUndoGrouping()
    #expect(undoManager.groupingLevel == 1)
    await updateValue(to: 4)
    undoManager.endUndoGrouping()
    #expect(undoManager.groupingLevel == 0)
    await updateValue(to: 5)

    #expect(undoManager.undoGroups.count == 2)
    #expect(undoManager.undoGroups.allSatisfy({ !$0.dos.isEmpty }))

    await undoManager.undo()
    await #expect(actor.value == 4)

    await undoManager.undo()
    await #expect(actor.value == 0)

    #expect(undoManager.canUndo == false)
    
    #expect(undoManager.redoGroups.count == 2)
    #expect(undoManager.redoGroups.allSatisfy({ !$0.dos.isEmpty }))
    
    await undoManager.redo()
    await #expect(actor.value == 4)

    #expect(undoManager.canUndo)
    #expect(undoManager.canRedo)
    
    #expect(undoManager.undoGroups.count == 1)
    #expect(undoManager.redoGroups.count == 1)
    #expect(undoManager.undoGroups.allSatisfy({ !$0.dos.isEmpty }))
    #expect(undoManager.redoGroups.allSatisfy({ !$0.dos.isEmpty }))
}
