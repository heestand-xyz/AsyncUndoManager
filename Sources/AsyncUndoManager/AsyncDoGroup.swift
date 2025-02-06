//
//  AsyncDoGroup.swift
//  AsyncUndoManager
//
//  Created by a-heestand on 2025/01/27.
//

import Foundation

public struct AsyncDoGroup: Identifiable {
    let metadata: AsyncDoGroupMetadata
    /// This `id` is determined by the current group the actions where registered in.
    ///
    /// If no group was started the id is the same as the first do id.
    public var id: UUID {
        metadata.id
    }
    /// This `name` is determined by the current group the actions where registered in.
    ///
    /// If no group was started the name is the same as the first do name.
    public var name: String? {
        metadata.name
    }
    /// If an object was attached in the beginning of the undo group, it will be available here.
    ///
    /// The object will persist over undos and redos.
    public var object: Any? {
        metadata.object
    }
    /// Will always contain at least one do.
    public var dos: [AsyncDo]
}
