import Foundation

struct VoicesResponse: Codable {
    let language: String
    let voices: [String]
    let regions: [StoryTimeRegion]?
}
