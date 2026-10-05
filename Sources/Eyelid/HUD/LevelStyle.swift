/// How the HUD draws the level to the right of the notch.
enum LevelStyle: String, CaseIterable, Sendable {
    case bar
    case thickBar
    case segments
    case percentage
    case ring

    var title: String {
        switch self {
        case .bar: "Bar"
        case .thickBar: "Thick bar"
        case .segments: "Segments"
        case .percentage: "Percentage"
        case .ring: "Ring"
        }
    }

    /// One segment per default step, like the 16 squares of the classic macOS HUD.
    static let segmentCount = 16

    static func litSegments(for level: Float) -> Int {
        min(max(Int((level * Float(segmentCount)).rounded()), 0), segmentCount)
    }
}
