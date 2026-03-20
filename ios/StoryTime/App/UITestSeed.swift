import Foundation

enum UITestSeed {
    static func prepareIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        let shouldSeed = environment["STORYTIME_UI_TEST_SEED"] == "1"
        let shouldReset = shouldSeed || environment["STORYTIME_UI_TEST_RESET"] == "1"
        guard shouldReset else { return }

        let defaults = UserDefaults.standard
        let keys = [
            "storytime.series.library.v1",
            "storytime.child.profiles.v1",
            "storytime.active.child.profile.v1",
            "storytime.parent.privacy.v1",
            "storytime.continuity.memory.v1",
            FirstRunExperienceStore.onboardingCompletedKey,
            "com.storytime.install-id",
            "com.storytime.entitlements.bootstrap.v1",
            "com.storytime.session-token",
            "com.storytime.session-expiry",
            "com.storytime.session-id"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        StoryLibraryV2Storage(storageURL: StoryLibraryV2Storage.defaultStorageURL()).clear()

        guard shouldSeed else { return }

        let primaryProfile = ChildProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            displayName: "Milo",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .bedtime
        )
        let secondaryProfile = ChildProfile(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            displayName: "Nora",
            age: 7,
            contentSensitivity: .standard,
            preferredMode: .educational
        )

        let now = Date()
        let firstEpisode = StoryEpisode(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
            title: "Bunny and the Lantern Trail",
            storyId: "seed-story-1",
            scenes: [
                StoryScene(sceneId: "1", text: "Bunny followed a glowing trail into the park.", durationSec: 45),
                StoryScene(sceneId: "2", text: "Fox helped Bunny find the missing lantern by the pond.", durationSec: 50)
            ],
            estimatedDurationSec: 95,
            engine: nil,
            createdAt: now.addingTimeInterval(-86_400)
        )
        let secondEpisode = StoryEpisode(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
            title: "Bunny and the Moonlight Map",
            storyId: "seed-story-2",
            scenes: [
                StoryScene(sceneId: "1", text: "Bunny found a moonlight map tucked inside the lantern.", durationSec: 48),
                StoryScene(sceneId: "2", text: "The map pointed toward a hidden garden behind the swings.", durationSec: 47)
            ],
            estimatedDurationSec: 95,
            engine: nil,
            createdAt: now
        )

        let seededSeries = StorySeries(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
            childProfileId: primaryProfile.id,
            title: "Bunny and the Lantern Trail",
            characterHints: ["Bunny", "Fox"],
            arcSummary: "Bunny keeps discovering clues that point toward a glowing hidden garden.",
            relationshipFacts: ["Bunny trusts Fox to solve quiet mysteries."],
            favoritePlaces: ["Moonlit Park", "Pond Path"],
            unresolvedThreads: ["What waits in the hidden garden?"],
            episodes: [firstEpisode, secondEpisode],
            createdAt: now.addingTimeInterval(-86_400),
            updatedAt: now
        )

        let privacy = ParentPrivacySettings(
            saveStoryHistory: true,
            retentionPolicy: .thirtyDays,
            saveRawAudio: false,
            clearTranscriptsAfterSession: true
        )

        defaults.set(try? JSONEncoder().encode([seededSeries]), forKey: "storytime.series.library.v1")
        defaults.set(try? JSONEncoder().encode([primaryProfile, secondaryProfile]), forKey: "storytime.child.profiles.v1")
        defaults.set(primaryProfile.id.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(try? JSONEncoder().encode(privacy), forKey: "storytime.parent.privacy.v1")
        defaults.set(true, forKey: FirstRunExperienceStore.onboardingCompletedKey)
        AppEntitlements.store(envelope: seededEntitlementEnvelope(childProfileCount: 2, environment: environment))
    }

    static func entitlementPreflightOverride(for plan: StoryLaunchPlan, childProfileCount: Int) -> EntitlementPreflightResponse? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["STORYTIME_UI_TEST_MODE"] == "1" else {
            return nil
        }

        let override = environment["STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch override {
        case "allow_new_story":
            guard case .new = plan.mode else { return nil }
            return EntitlementPreflightResponse(
                action: .newStory,
                allowed: true,
                blockReason: nil,
                recommendedUpgradeSurface: nil,
                snapshot: allowedSnapshot(
                    tier: seededTier(environment: environment),
                    childProfileCount: childProfileCount,
                    remainingStoryStarts: 1,
                    remainingContinuations: 1,
                    environment: environment
                )
            )
        case "allow_continue_story":
            guard case .extend = plan.mode else { return nil }
            return EntitlementPreflightResponse(
                action: .continueStory,
                allowed: true,
                blockReason: nil,
                recommendedUpgradeSurface: nil,
                snapshot: allowedSnapshot(
                    tier: seededTier(environment: environment),
                    childProfileCount: childProfileCount,
                    remainingStoryStarts: 1,
                    remainingContinuations: 1,
                    environment: environment
                )
            )
        case "block_new_story":
            guard case .new = plan.mode else { return nil }
            if AppEntitlements.currentSnapshot?.tier == .plus {
                return EntitlementPreflightResponse(
                    action: .newStory,
                    allowed: true,
                    blockReason: nil,
                    recommendedUpgradeSurface: nil,
                    snapshot: allowedSnapshot(
                        tier: .plus,
                        childProfileCount: childProfileCount,
                        remainingStoryStarts: 1,
                        remainingContinuations: 1,
                        environment: environment
                    )
                )
            }
            return EntitlementPreflightResponse(
                action: .newStory,
                allowed: false,
                blockReason: .storyStartsExhausted,
                recommendedUpgradeSurface: .newStoryJourney,
                snapshot: blockedStarterSnapshot(
                    childProfileCount: childProfileCount,
                    canStartNewStories: false,
                    canContinueSavedSeries: true,
                    remainingStoryStarts: 0,
                    remainingContinuations: 1,
                    environment: environment
                )
            )
        case "block_continue_story":
            guard case .extend = plan.mode else { return nil }
            if AppEntitlements.currentSnapshot?.tier == .plus {
                return EntitlementPreflightResponse(
                    action: .continueStory,
                    allowed: true,
                    blockReason: nil,
                    recommendedUpgradeSurface: nil,
                    snapshot: allowedSnapshot(
                        tier: .plus,
                        childProfileCount: childProfileCount,
                        remainingStoryStarts: 1,
                        remainingContinuations: 1,
                        environment: environment
                    )
                )
            }
            return EntitlementPreflightResponse(
                action: .continueStory,
                allowed: false,
                blockReason: .continuationsExhausted,
                recommendedUpgradeSurface: .storySeriesDetail,
                snapshot: blockedStarterSnapshot(
                    childProfileCount: childProfileCount,
                    canStartNewStories: true,
                    canContinueSavedSeries: false,
                    remainingStoryStarts: 1,
                    remainingContinuations: 0,
                    environment: environment
                )
            )
        default:
            guard let request = EntitlementPreflightRequest(plan: plan, childProfileCount: childProfileCount),
                  let snapshot = AppEntitlements.currentSnapshot else {
                return nil
            }
            return defaultPreflightResponse(for: request, snapshot: snapshot)
        }
    }

    static func parentManagedPurchaseProviderIfNeeded() -> (any ParentManagedPurchaseProviding)? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["STORYTIME_UI_TEST_MODE"] == "1" else {
            return nil
        }

        return UITestParentManagedPurchaseProvider(environment: environment)
    }

    private static func defaultPreflightResponse(
        for request: EntitlementPreflightRequest,
        snapshot: EntitlementSnapshot
    ) -> EntitlementPreflightResponse {
        let upgradeSurface: EntitlementUpgradeSurface = request.action == .newStory ? .newStoryJourney : .storySeriesDetail
        let childProfileAllowed = request.childProfileCount <= snapshot.maxChildProfiles
        let lengthAllowed = snapshot.maxStoryLengthMinutes.map { request.requestedLengthMinutes <= $0 } ?? true

        let actionAllowed: Bool
        let remainingAllowed: Bool
        let blockReason: EntitlementPreflightBlockReason?

        switch request.action {
        case .newStory:
            actionAllowed = snapshot.canStartNewStories
            remainingAllowed = (snapshot.remainingStoryStarts ?? 1) > 0
            if !childProfileAllowed {
                blockReason = .childProfileLimit
            } else if !lengthAllowed {
                blockReason = .storyLengthExceeded
            } else if !actionAllowed {
                blockReason = .newStoryNotAllowed
            } else if !remainingAllowed {
                blockReason = .storyStartsExhausted
            } else {
                blockReason = nil
            }
        case .continueStory:
            actionAllowed = snapshot.canContinueSavedSeries
            remainingAllowed = (snapshot.remainingContinuations ?? 1) > 0
            if !childProfileAllowed {
                blockReason = .childProfileLimit
            } else if !lengthAllowed {
                blockReason = .storyLengthExceeded
            } else if !actionAllowed {
                blockReason = .continuationNotAllowed
            } else if !remainingAllowed {
                blockReason = .continuationsExhausted
            } else {
                blockReason = nil
            }
        }

        return EntitlementPreflightResponse(
            action: request.action,
            allowed: blockReason == nil,
            blockReason: blockReason,
            recommendedUpgradeSurface: blockReason == nil ? nil : upgradeSurface,
            snapshot: snapshot
        )
    }

    private static func blockedStarterSnapshot(
        childProfileCount: Int,
        canStartNewStories: Bool,
        canContinueSavedSeries: Bool,
        remainingStoryStarts: Int?,
        remainingContinuations: Int?,
        environment: [String: String]
    ) -> EntitlementSnapshot {
        let now = Date()
        let tier = seededTier(environment: environment)
        return EntitlementSnapshot(
            tier: tier,
            source: .debugSeed,
            maxChildProfiles: resolvedMaxChildProfiles(for: tier, childProfileCount: childProfileCount, environment: environment),
            maxStoryStartsPerPeriod: resolvedLimit(
                environment["STORYTIME_UI_TEST_MAX_STORY_STARTS"],
                defaultValue: tier == .plus ? 4 : 1
            ),
            maxContinuationsPerPeriod: resolvedLimit(
                environment["STORYTIME_UI_TEST_MAX_CONTINUATIONS"],
                defaultValue: tier == .plus ? 4 : 1
            ),
            maxStoryLengthMinutes: resolvedLimit(environment["STORYTIME_UI_TEST_MAX_STORY_LENGTH"], defaultValue: 10),
            canReplaySavedStories: true,
            canStartNewStories: canStartNewStories,
            canContinueSavedSeries: canContinueSavedSeries,
            effectiveAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(300).timeIntervalSince1970,
            usageWindow: EntitlementUsageWindow(
                kind: .rollingPeriod,
                durationSeconds: 86_400,
                resetsAt: now.addingTimeInterval(86_400).timeIntervalSince1970
            ),
            remainingStoryStarts: remainingStoryStarts,
            remainingContinuations: remainingContinuations
        )
    }

    fileprivate static func seededEntitlementEnvelope(childProfileCount: Int, environment: [String: String]) -> EntitlementBootstrapEnvelope {
        let now = Date()
        let tier = seededTier(environment: environment)
        let snapshot = EntitlementSnapshot(
            tier: tier,
            source: .debugSeed,
            maxChildProfiles: resolvedMaxChildProfiles(for: tier, childProfileCount: childProfileCount, environment: environment),
            maxStoryStartsPerPeriod: resolvedLimit(
                environment["STORYTIME_UI_TEST_MAX_STORY_STARTS"],
                defaultValue: tier == .plus ? 4 : 1
            ),
            maxContinuationsPerPeriod: resolvedLimit(
                environment["STORYTIME_UI_TEST_MAX_CONTINUATIONS"],
                defaultValue: tier == .plus ? 4 : 1
            ),
            maxStoryLengthMinutes: resolvedLimit(environment["STORYTIME_UI_TEST_MAX_STORY_LENGTH"], defaultValue: 10),
            canReplaySavedStories: true,
            canStartNewStories: true,
            canContinueSavedSeries: true,
            effectiveAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(600).timeIntervalSince1970,
            usageWindow: EntitlementUsageWindow(
                kind: .rollingPeriod,
                durationSeconds: 86_400,
                resetsAt: now.addingTimeInterval(86_400).timeIntervalSince1970
            ),
            remainingStoryStarts: 1,
            remainingContinuations: 1
        )

        return EntitlementBootstrapEnvelope(
            snapshot: snapshot,
            token: "ui-seeded-entitlement-token",
            expiresAt: now.addingTimeInterval(600).timeIntervalSince1970
        )
    }

    private static func allowedSnapshot(
        tier: EntitlementTier,
        childProfileCount: Int,
        remainingStoryStarts: Int?,
        remainingContinuations: Int?,
        environment: [String: String]
    ) -> EntitlementSnapshot {
        let now = Date()
        return EntitlementSnapshot(
            tier: tier,
            source: .debugSeed,
            maxChildProfiles: resolvedMaxChildProfiles(for: tier, childProfileCount: childProfileCount, environment: environment),
            maxStoryStartsPerPeriod: resolvedLimit(
                environment["STORYTIME_UI_TEST_MAX_STORY_STARTS"],
                defaultValue: tier == .plus ? 4 : 1
            ),
            maxContinuationsPerPeriod: resolvedLimit(
                environment["STORYTIME_UI_TEST_MAX_CONTINUATIONS"],
                defaultValue: tier == .plus ? 4 : 1
            ),
            maxStoryLengthMinutes: resolvedLimit(environment["STORYTIME_UI_TEST_MAX_STORY_LENGTH"], defaultValue: 10),
            canReplaySavedStories: true,
            canStartNewStories: true,
            canContinueSavedSeries: true,
            effectiveAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(300).timeIntervalSince1970,
            usageWindow: EntitlementUsageWindow(
                kind: .rollingPeriod,
                durationSeconds: 86_400,
                resetsAt: now.addingTimeInterval(86_400).timeIntervalSince1970
            ),
            remainingStoryStarts: remainingStoryStarts,
            remainingContinuations: remainingContinuations
        )
    }

    private static func seededTier(environment: [String: String]) -> EntitlementTier {
        environment["STORYTIME_UI_TEST_ENTITLEMENT_TIER"]?.lowercased() == "plus" ? .plus : .starter
    }

    private static func resolvedMaxChildProfiles(
        for tier: EntitlementTier,
        childProfileCount: Int,
        environment: [String: String]
    ) -> Int {
        let override = resolvedLimit(environment["STORYTIME_UI_TEST_MAX_CHILD_PROFILES"], defaultValue: -1)
        if override > 0 {
            return override
        }

        return tier == .plus ? max(3, childProfileCount + 1) : max(1, childProfileCount)
    }

    private static func resolvedLimit(_ rawValue: String?, defaultValue: Int) -> Int {
        guard let rawValue, let value = Int(rawValue), value > 0 else {
            return defaultValue
        }

        return value
    }
}

private struct UITestParentManagedPurchaseProvider: ParentManagedPurchaseProviding {
    let environment: [String: String]

    func availableOptions() async throws -> [ParentManagedPurchaseOption] {
        guard AppEntitlements.currentSnapshot?.tier != .plus else { return [] }

        return [
            ParentManagedPurchaseOption(
                productID: "storytime.plus.monthly",
                displayName: "Plus Monthly",
                displayPrice: "$4.99"
            )
        ]
    }

    func purchase(productID: String) async throws -> ParentManagedPurchaseOutcome {
        switch environment["STORYTIME_UI_TEST_PURCHASE_RESULT"]?.lowercased() {
        case "cancelled":
            return .cancelled
        case "pending":
            return .pending
        default:
            var plusEnvironment = environment
            plusEnvironment["STORYTIME_UI_TEST_ENTITLEMENT_TIER"] = "plus"
            let envelope = UITestSeed.seededEntitlementEnvelope(
                childProfileCount: seededChildProfileCount(),
                environment: plusEnvironment
            )
            AppEntitlements.store(envelope: envelope)
            return .purchased(syncRequest: nil)
        }
    }

    private func seededChildProfileCount() -> Int {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "storytime.child.profiles.v1"),
              let profiles = try? JSONDecoder().decode([ChildProfile].self, from: data) else {
            return 1
        }

        return max(profiles.count, 1)
    }
}
