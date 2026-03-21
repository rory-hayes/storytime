import XCTest
@testable import StoryTime

@MainActor
final class ParentAuthManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppEntitlements.clear()
    }

    override func tearDown() {
        AppEntitlements.clear()
        super.tearDown()
    }

    func testManagerStartsSignedOutWhenProviderHasNoUser() {
        let provider = StubParentAuthProvider(currentUser: nil)

        let manager = ParentAuthManager(provider: provider)

        XCTAssertEqual(manager.authState, .signedOut)
        XCTAssertFalse(manager.isSignedIn)
        XCTAssertEqual(manager.accountStatusTitle, "Parent account not signed in")
        XCTAssertEqual(
            manager.accountStatusSummary,
            "Firebase Auth is ready on this device, but no parent account is signed in yet. Child story screens stay sign-in-free."
        )
    }

    func testManagerStartsSignedInWhenProviderHasCurrentUser() {
        let user = ParentAuthUser(uid: "parent-1", email: "parent@example.com", isAnonymous: false, signInMethod: .emailPassword)
        let provider = StubParentAuthProvider(currentUser: user)

        let manager = ParentAuthManager(provider: provider)

        XCTAssertEqual(manager.authState, .signedIn(user))
        XCTAssertTrue(manager.isSignedIn)
        XCTAssertEqual(manager.accountStatusTitle, "parent@example.com")
        XCTAssertEqual(
            manager.accountStatusSummary,
            "Firebase Auth is active for parent@example.com. Account, purchase, and promo work stay in parent-managed surfaces."
        )
    }

    func testManagerRespondsToAuthStateChanges() {
        let provider = StubParentAuthProvider(currentUser: nil)
        let manager = ParentAuthManager(provider: provider)
        let signedInUser = ParentAuthUser(uid: "parent-2", email: "grownup@example.com", isAnonymous: false, signInMethod: .emailPassword)

        provider.emit(user: signedInUser)
        XCTAssertEqual(manager.authState, .signedIn(signedInUser))
        XCTAssertTrue(manager.isSignedIn)

        provider.emit(user: nil)
        XCTAssertEqual(manager.authState, .signedOut)
        XCTAssertFalse(manager.isSignedIn)
    }

    func testCreateAccountSignsParentIn() async {
        let provider = StubParentAuthProvider(currentUser: nil)
        let manager = ParentAuthManager(provider: provider)

        let success = await manager.createAccount(email: "parent@example.com", password: "secret1")

        XCTAssertTrue(success)
        XCTAssertEqual(
            manager.authState,
            .signedIn(ParentAuthUser(uid: "created-parent", email: "parent@example.com", isAnonymous: false, signInMethod: .emailPassword))
        )
        XCTAssertNil(manager.authErrorMessage)
    }

    func testSignInWithAppleSignsParentInAndUsesAppleFallbackCopy() async {
        let provider = StubParentAuthProvider(currentUser: nil)
        let manager = ParentAuthManager(provider: provider)

        let success = await manager.signInWithApple()

        XCTAssertTrue(success)
        XCTAssertEqual(
            manager.authState,
            .signedIn(ParentAuthUser(uid: "apple-parent", email: nil, isAnonymous: false, signInMethod: .apple))
        )
        XCTAssertEqual(manager.accountStatusTitle, "Parent account signed in with Apple")
        XCTAssertEqual(
            manager.accountStatusSummary,
            "Firebase Auth is active for this parent via Sign in with Apple. Account, purchase, and promo work stay in parent-managed surfaces."
        )
        XCTAssertNil(manager.authErrorMessage)
    }

    func testSignInFailureShowsSafeMessage() async {
        let provider = StubParentAuthProvider(
            currentUser: nil,
            signInError: .invalidCredentials
        )
        let manager = ParentAuthManager(provider: provider)

        let success = await manager.signIn(email: "parent@example.com", password: "wrongpass")

        XCTAssertFalse(success)
        XCTAssertEqual(manager.authState, .signedOut)
        XCTAssertEqual(
            manager.authErrorMessage,
            "That email and password do not match a parent account yet."
        )
    }

    func testSignInWithAppleCancellationShowsSafeMessage() async {
        let provider = StubParentAuthProvider(
            currentUser: nil,
            signInWithAppleError: .cancelled
        )
        let manager = ParentAuthManager(provider: provider)

        let success = await manager.signInWithApple()

        XCTAssertFalse(success)
        XCTAssertEqual(manager.authState, .signedOut)
        XCTAssertEqual(manager.authErrorMessage, "Sign in with Apple was cancelled.")
    }

    func testSignOutClearsSignedInState() {
        let currentUser = ParentAuthUser(uid: "signed-in-parent", email: "parent@example.com", isAnonymous: false, signInMethod: .emailPassword)
        let provider = StubParentAuthProvider(currentUser: currentUser)
        let manager = ParentAuthManager(provider: provider)

        let success = manager.signOut()

        XCTAssertTrue(success)
        XCTAssertEqual(manager.authState, .signedOut)
        XCTAssertFalse(manager.isSignedIn)
        XCTAssertNil(manager.authErrorMessage)
    }

    func testSignOutClearsCachedParentOwnedEntitlements() {
        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: makeSnapshot(tier: .plus),
                token: "parent-owned-token",
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                owner: EntitlementOwner(kind: .parentUser, parentUserID: "signed-in-parent", authProvider: .firebase)
            )
        )
        let currentUser = ParentAuthUser(uid: "signed-in-parent", email: "parent@example.com", isAnonymous: false, signInMethod: .emailPassword)
        let provider = StubParentAuthProvider(currentUser: currentUser)
        let manager = ParentAuthManager(provider: provider)

        XCTAssertEqual(AppEntitlements.currentOwner?.parentUserID, "signed-in-parent")

        let success = manager.signOut()

        XCTAssertTrue(success)
        XCTAssertNil(AppEntitlements.currentEnvelope)
    }

    func testSwitchingParentsClearsCachedEntitlementsOwnedByDifferentParent() {
        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: makeSnapshot(tier: .plus),
                token: "parent-a-token",
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                owner: EntitlementOwner(kind: .parentUser, parentUserID: "parent-a", authProvider: .firebase)
            )
        )
        let provider = StubParentAuthProvider(
            currentUser: ParentAuthUser(uid: "parent-a", email: "a@example.com", isAnonymous: false, signInMethod: .emailPassword)
        )
        let manager = ParentAuthManager(provider: provider)

        provider.emit(
            user: ParentAuthUser(uid: "parent-b", email: "b@example.com", isAnonymous: false, signInMethod: .emailPassword)
        )

        XCTAssertEqual(manager.currentUser?.uid, "parent-b")
        XCTAssertNil(AppEntitlements.currentEnvelope)
    }

    func testSignOutRestoresLastInstallOwnedEntitlementSnapshot() {
        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: makeSnapshot(tier: .starter),
                token: "install-token",
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                owner: EntitlementOwner(kind: .install)
            )
        )
        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: makeSnapshot(tier: .plus),
                token: "parent-owned-token",
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                owner: EntitlementOwner(kind: .parentUser, parentUserID: "signed-in-parent", authProvider: .firebase)
            )
        )
        let currentUser = ParentAuthUser(uid: "signed-in-parent", email: "parent@example.com", isAnonymous: false, signInMethod: .emailPassword)
        let provider = StubParentAuthProvider(currentUser: currentUser)
        let manager = ParentAuthManager(provider: provider)

        let success = manager.signOut()

        XCTAssertTrue(success)
        XCTAssertEqual(AppEntitlements.currentSnapshot?.tier, .starter)
        XCTAssertEqual(AppEntitlements.currentOwner?.kind, .install)
    }
}

private func makeSnapshot(tier: EntitlementTier) -> EntitlementSnapshot {
    EntitlementSnapshot(
        tier: tier,
        source: tier == .plus ? .storekitVerified : .none,
        maxChildProfiles: tier == .plus ? 3 : 1,
        maxStoryStartsPerPeriod: tier == .plus ? 12 : 3,
        maxContinuationsPerPeriod: tier == .plus ? 12 : 3,
        maxStoryLengthMinutes: 10,
        canReplaySavedStories: true,
        canStartNewStories: true,
        canContinueSavedSeries: true,
        effectiveAt: Date().addingTimeInterval(-60).timeIntervalSince1970,
        expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
        usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: 604_800, resetsAt: nil),
        remainingStoryStarts: tier == .plus ? 12 : 3,
        remainingContinuations: tier == .plus ? 12 : 3
    )
}

@MainActor
private final class StubParentAuthProvider: ParentAuthProviding {
    var currentUser: ParentAuthUser?
    var createUserError: ParentAuthProviderError?
    var signInError: ParentAuthProviderError?
    var signInWithAppleError: ParentAuthProviderError?
    var signOutError: ParentAuthProviderError?

    private var observers: [UUID: @MainActor (ParentAuthUser?) -> Void] = [:]

    init(
        currentUser: ParentAuthUser?,
        createUserError: ParentAuthProviderError? = nil,
        signInError: ParentAuthProviderError? = nil,
        signInWithAppleError: ParentAuthProviderError? = nil,
        signOutError: ParentAuthProviderError? = nil
    ) {
        self.currentUser = currentUser
        self.createUserError = createUserError
        self.signInError = signInError
        self.signInWithAppleError = signInWithAppleError
        self.signOutError = signOutError
    }

    @discardableResult
    func addAuthStateObserver(_ observer: @escaping @MainActor (ParentAuthUser?) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeAuthStateObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }

    func createUser(email: String, password: String) async throws -> ParentAuthUser {
        if let createUserError {
            throw createUserError
        }

        let user = ParentAuthUser(uid: "created-parent", email: email, isAnonymous: false, signInMethod: .emailPassword)
        emit(user: user)
        return user
    }

    func signIn(email: String, password: String) async throws -> ParentAuthUser {
        if let signInError {
            throw signInError
        }

        let user = ParentAuthUser(uid: "signed-in-parent", email: email, isAnonymous: false, signInMethod: .emailPassword)
        emit(user: user)
        return user
    }

    func signInWithApple() async throws -> ParentAuthUser {
        if let signInWithAppleError {
            throw signInWithAppleError
        }

        let user = ParentAuthUser(uid: "apple-parent", email: nil, isAnonymous: false, signInMethod: .apple)
        emit(user: user)
        return user
    }

    func signOut() throws {
        if let signOutError {
            throw signOutError
        }

        emit(user: nil)
    }

    func emit(user: ParentAuthUser?) {
        currentUser = user
        for observer in observers.values {
            observer(user)
        }
    }
}
