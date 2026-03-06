import XCTest
@testable import StoryTime

final class AnalysisModelTests: XCTestCase {
    func testStoryDataDecodingProvidesDefaultsForOptionalEngineCollections() throws {
        let json = """
        {
          "story_id": "story-1",
          "title": "Lantern Trail",
          "estimated_duration_sec": 120,
          "scenes": [
            {
              "scene_id": "scene-1",
              "text": "Bunny followed the lantern home.",
              "duration_sec": 40
            }
          ],
          "safety": {
            "input_moderation": "pass",
            "output_moderation": "pass"
          },
          "engine": {
            "episode_recap": "Bunny followed the lantern trail.",
            "series_memory": {}
          }
        }
        """

        let decoded = try JSONDecoder().decode(StoryData.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.scenes.first?.id, "scene-1")
        XCTAssertEqual(decoded.engine?.seriesMemory.recurringCharacters, [])
        XCTAssertEqual(decoded.engine?.seriesMemory.worldFacts, [])
        XCTAssertEqual(decoded.engine?.seriesMemory.openLoops, [])
        XCTAssertEqual(decoded.engine?.seriesMemory.favoritePlaces, [])
        XCTAssertEqual(decoded.engine?.seriesMemory.relationshipFacts, [])
        XCTAssertEqual(decoded.engine?.characterBible, [])
        XCTAssertEqual(decoded.engine?.beatPlan, [])
        XCTAssertEqual(decoded.engine?.continuityFacts, [])
        XCTAssertNil(decoded.engine?.quality)
    }

    func testRequestsEncodeUsingBackendFieldNames() throws {
        let generate = GenerateStoryRequest(
            childProfileId: "child-1",
            ageBand: "3-8",
            language: "en",
            lengthMinutes: 4,
            voice: "alloy",
            questionCount: 2,
            storyBrief: StoryBrief(
                theme: "a sleepy cloud adventure",
                characters: ["Bunny"],
                setting: "the cloud village",
                tone: "calm",
                episodeIntent: "continue the series",
                lesson: "kindness"
            ),
            continuityFacts: ["Place: cloud village"]
        )
        let revise = ReviseStoryRequest(
            storyId: "story-1",
            currentSceneIndex: 1,
            storyTitle: "Cloud Village",
            userUpdate: "Add a moon clue",
            completedScenes: [],
            remainingScenes: []
        )

        let generateObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(generate)) as? [String: Any]
        )
        let brief = try XCTUnwrap(generateObject["story_brief"] as? [String: Any])
        let reviseObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(revise)) as? [String: Any]
        )

        XCTAssertEqual(generateObject["child_profile_id"] as? String, "child-1")
        XCTAssertEqual(generateObject["length_minutes"] as? Int, 4)
        XCTAssertEqual(brief["episode_intent"] as? String, "continue the series")
        XCTAssertEqual(reviseObject["story_id"] as? String, "story-1")
        XCTAssertEqual(reviseObject["current_scene_index"] as? Int, 1)
        XCTAssertEqual(reviseObject["user_update"] as? String, "Add a moon clue")
    }
}
