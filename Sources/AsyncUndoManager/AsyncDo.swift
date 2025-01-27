import Foundation

public struct AsyncDo: Identifiable, Sendable {
    public let id: UUID
    public let group: (id: UUID, name: String?)?
    public let name: String?
    let action: @Sendable () async -> Void
}
