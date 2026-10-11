# AsyncUndoManager

Attempting to mirror the API of [Apple's UndoManager](https://developer.apple.com/documentation/foundation/undomanager) with support for concurrency.

It supports registering asynchronous undo actions, grouping them, and limiting the number of undo levels.

Note that while undoing or redoing, parallel requests to undo and redo will be blocked.

## Swift Package

```swift
.package(url: "https://github.com/heestand-xyz/AsyncUndoManager", from: "1.0.0")
```

## Example

```swift
import AsyncUndoManager

@MainActor
func example() async {
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
    await undoManager.undo()
    await undoManager.redo()
}
```

## Grouped Example

You can group multiple undo actions so that a single undo operation reverts a set of changes.

```swift
@MainActor
func groupedExample() async {
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
    await undoManager.undo()
    await undoManager.undo()
}
```

> Note that these examples are simplified, please refer to the unit tests for more detailed examples.

## Failure-aware actions

`registerUndoAttempt(named:_:)` accepts an asynchronous action returning `Bool`. Return
`false` only when the attempted inverse left the graph unchanged and registered no
new inverse. The same entry remains available for retry, and undo-all/redo-all stop
at that entry. Return `true` after completing the change and registering its inverse.
The existing `registerUndo` API retains its unconditional-success behavior. Grouping
does not roll back earlier successful members when a later member fails.
