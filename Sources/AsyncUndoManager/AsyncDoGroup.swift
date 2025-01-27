//
//  AsyncDoGroup.swift
//  AsyncUndoManager
//
//  Created by a-heestand on 2025/01/27.
//

import Foundation

public struct AsyncDoGroup: Identifiable {
    /// This `id` is determined by the current group the actions where registered in.
    ///
    /// If no group was started the id is the same as the first do id.
    public let id: UUID
    /// This `name` is determined by the current group the actions where registered in.
    ///
    /// If no group was started the name is the same as the first do name.
    public let name: String?
    /// Will always contain at least one do.
    public var dos: [AsyncDo]
}
