//
//  AsyncDoGroupMetadata.swift
//  AsyncUndoManager
//
//  Created by a-heestand on 2025/01/27.
//

import Foundation

struct AsyncDoGroupMetadata: Sendable {
    let id: UUID
    let name: String?
    let object: Sendable?
}
