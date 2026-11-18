import Foundation

public struct ScreenshotItem: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { name }
    public let index: Int
    public let name: String
    public let url: URL
    public let secondsDisplay: String
    public let sortKey: Int
    public var previewNewName: String?

    public init(
        index: Int,
        name: String,
        url: URL,
        secondsDisplay: String,
        sortKey: Int,
        previewNewName: String? = nil
    ) {
        self.index = index
        self.name = name
        self.url = url
        self.secondsDisplay = secondsDisplay
        self.sortKey = sortKey
        self.previewNewName = previewNewName
    }
}
