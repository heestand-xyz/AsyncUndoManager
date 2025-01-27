//
//  AsyncDoGroup.swift
//  AsyncUndoManager
//
//  Created by a-heestand on 2025/01/27.
//

import Foundation

public struct AsyncDoGroup: Identifiable {
    public let id: UUID
    public let name: String?
    public var dos: [AsyncDo]
}
