import Foundation

public struct AsyncDo: Identifiable, Sendable {
    public let id: UUID
    let groupMetadata: AsyncDoGroupMetadata?
    public let name: String?
    let action: @Sendable () async -> Void
}
