import Foundation
import Combine
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum ParentAuthSignInMethod: String, Codable, Equatable {
    case emailPassword
    case apple
}

struct ParentAuthUser: Equatable, Codable {
    let uid: String
    let email: String?
    let isAnonymous: Bool
    let signInMethod: ParentAuthSignInMethod
}

enum ParentAuthProviderError: Error, Equatable {
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case invalidCredentials
    case cancelled
    case network
    case rateLimited
    case unavailable
    case unknown
}

protocol ParentAuthProviding: AnyObject {
    var currentUser: ParentAuthUser? { get }
    @discardableResult
    func addAuthStateObserver(_ observer: @escaping @MainActor (ParentAuthUser?) -> Void) -> UUID
    func removeAuthStateObserver(id: UUID)
    func createUser(email: String, password: String) async throws -> ParentAuthUser
    func signIn(email: String, password: String) async throws -> ParentAuthUser
    func signInWithApple() async throws -> ParentAuthUser
    func signOut() throws
}

@MainActor
final class ParentAuthManager: ObservableObject {
    enum AuthState: Equatable {
        case signedOut
        case signedIn(ParentAuthUser)
    }

    @Published private(set) var authState: AuthState
    @Published private(set) var isPerformingAccountAction = false
    @Published private(set) var authErrorMessage: String?

    private let provider: ParentAuthProviding
    private var observerID: UUID?

    init(provider: ParentAuthProviding = FirebaseParentAuthProvider()) {
        self.provider = provider
        self.authState = Self.state(from: provider.currentUser)
        AppEntitlements.reconcileForParentChange(currentParentUserID: provider.currentUser?.uid)
        observerID = provider.addAuthStateObserver { [weak self] user in
            self?.applyAuthState(for: user)
        }
    }

    deinit {
        if let observerID {
            provider.removeAuthStateObserver(id: observerID)
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = authState {
            return true
        }

        return false
    }

    var currentUser: ParentAuthUser? {
        if case let .signedIn(user) = authState {
            return user
        }

        return nil
    }

    var accountStatusTitle: String {
        switch authState {
        case .signedOut:
            return "Parent account not signed in"
        case let .signedIn(user):
            return user.email ?? Self.fallbackSignedInTitle(for: user)
        }
    }

    var accountStatusSummary: String {
        switch authState {
        case .signedOut:
            return "Firebase Auth is ready on this device, but no parent account is signed in yet. Child story screens stay sign-in-free."
        case let .signedIn(user):
            let identity = user.email ?? Self.fallbackSignedInIdentity(for: user)
            return "Firebase Auth is active for \(identity). Account, purchase, and promo work stay in parent-managed surfaces."
        }
    }

    func reloadCurrentState() {
        applyAuthState(for: provider.currentUser)
    }

    func clearAuthError() {
        authErrorMessage = nil
    }

    func createAccount(email: String, password: String) async -> Bool {
        await performAccountAction(
            action: .createAccount
        ) { provider in
            try await provider.createUser(email: Self.normalizedEmail(email), password: password)
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        await performAccountAction(
            action: .signIn
        ) { provider in
            try await provider.signIn(email: Self.normalizedEmail(email), password: password)
        }
    }

    func signInWithApple() async -> Bool {
        await performAccountAction(
            action: .signInWithApple
        ) { provider in
            try await provider.signInWithApple()
        }
    }

    func signOut() -> Bool {
        authErrorMessage = nil

        do {
            try provider.signOut()
            applyAuthState(for: nil)
            return true
        } catch let error as ParentAuthProviderError {
            authErrorMessage = Self.message(for: error, action: .signOut)
            return false
        } catch {
            authErrorMessage = Self.message(for: .unknown, action: .signOut)
            return false
        }
    }

    private static func state(from user: ParentAuthUser?) -> AuthState {
        if let user {
            return .signedIn(user)
        }

        return .signedOut
    }

    private func applyAuthState(for user: ParentAuthUser?) {
        AppEntitlements.reconcileForParentChange(currentParentUserID: user?.uid)
        authState = Self.state(from: user)
    }

    private func performAccountAction(
        action: AccountAction,
        operation: @escaping (ParentAuthProviding) async throws -> ParentAuthUser
    ) async -> Bool {
        authErrorMessage = nil
        isPerformingAccountAction = true
        defer { isPerformingAccountAction = false }

        do {
            let user = try await operation(provider)
            applyAuthState(for: user)
            return true
        } catch let error as ParentAuthProviderError {
            authErrorMessage = Self.message(for: error, action: action)
            return false
        } catch {
            authErrorMessage = Self.message(for: .unknown, action: action)
            return false
        }
    }

    private static func message(for error: ParentAuthProviderError, action: AccountAction) -> String {
        switch (action, error) {
        case (_, .invalidEmail):
            return "Enter a valid parent email address."
        case (.createAccount, .emailAlreadyInUse):
            return "That email already has a parent account. Try signing in instead."
        case (.createAccount, .weakPassword):
            return "Use a password with at least 6 characters."
        case (.signIn, .invalidCredentials):
            return "That email and password do not match a parent account yet."
        case (.signInWithApple, .cancelled):
            return "Sign in with Apple was cancelled."
        case (.signInWithApple, .unavailable):
            return "Sign in with Apple isn't available on this device right now."
        case (_, .network):
            return "I couldn't reach parent account sign-in right now. Ask a grown-up to try again."
        case (_, .rateLimited):
            return "Too many parent sign-in attempts right now. Ask a grown-up to try again later."
        case (.signOut, _):
            return "I couldn't sign out right now. Ask a grown-up to try again."
        default:
            return "I couldn't update the parent account right now. Ask a grown-up to try again."
        }
    }

    private static func fallbackSignedInTitle(for user: ParentAuthUser) -> String {
        switch user.signInMethod {
        case .apple:
            return "Parent account signed in with Apple"
        case .emailPassword:
            return "Parent account signed in"
        }
    }

    private static func fallbackSignedInIdentity(for user: ParentAuthUser) -> String {
        switch user.signInMethod {
        case .apple:
            return "this parent via Sign in with Apple"
        case .emailPassword:
            return "this parent account"
        }
    }

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension ParentAuthManager {
    enum AccountAction {
        case createAccount
        case signIn
        case signInWithApple
        case signOut
    }
}

#if canImport(FirebaseAuth)
final class FirebaseParentAuthProvider: ParentAuthProviding {
    private var handles: [UUID: AuthStateDidChangeListenerHandle] = [:]

    init() {}

    var currentUser: ParentAuthUser? {
        resolvedAuth().currentUser.map(Self.map(user:))
    }

    @discardableResult
    func addAuthStateObserver(_ observer: @escaping @MainActor (ParentAuthUser?) -> Void) -> UUID {
        let id = UUID()
        let handle = resolvedAuth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                observer(user.map(Self.map(user:)))
            }
        }
        handles[id] = handle
        return id
    }

    func removeAuthStateObserver(id: UUID) {
        guard let handle = handles.removeValue(forKey: id) else { return }
        resolvedAuth().removeStateDidChangeListener(handle)
    }

    func createUser(email: String, password: String) async throws -> ParentAuthUser {
        let user: ParentAuthUser = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ParentAuthUser, Error>) in
            resolvedAuth().createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: Self.map(error: error))
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: ParentAuthProviderError.unknown)
                    return
                }

                continuation.resume(returning: Self.map(user: user))
            }
        }

        return user
    }

    func signIn(email: String, password: String) async throws -> ParentAuthUser {
        let user: ParentAuthUser = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ParentAuthUser, Error>) in
            resolvedAuth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: Self.map(error: error))
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: ParentAuthProviderError.unknown)
                    return
                }

                continuation.resume(returning: Self.map(user: user))
            }
        }

        return user
    }

    func signInWithApple() async throws -> ParentAuthUser {
        let rawNonce = Self.randomNonce()
        let appleCredential = try await AppleSignInCoordinator().requestCredential(rawNonce: rawNonce)

        guard let identityToken = appleCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            throw ParentAuthProviderError.unknown
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityTokenString,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )

        let user: ParentAuthUser = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ParentAuthUser, Error>) in
            resolvedAuth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: Self.map(error: error))
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: ParentAuthProviderError.unknown)
                    return
                }

                continuation.resume(returning: Self.map(user: user))
            }
        }

        return user
    }

    func signOut() throws {
        do {
            try resolvedAuth().signOut()
        } catch {
            throw Self.map(error: error)
        }
    }

    private static func map(user: FirebaseAuth.User) -> ParentAuthUser {
        ParentAuthUser(
            uid: user.uid,
            email: user.email,
            isAnonymous: user.isAnonymous,
            signInMethod: signInMethod(for: user)
        )
    }

    private static func map(error: Error) -> ParentAuthProviderError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown
        }

        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .webContextCancelled, .secondFactorRequired:
            return .cancelled
        case .wrongPassword, .invalidCredential, .userNotFound:
            return .invalidCredentials
        case .networkError:
            return .network
        case .tooManyRequests:
            return .rateLimited
        default:
            return .unknown
        }
    }

    private func resolvedAuth() -> Auth {
        Auth.auth()
    }

    private static func signInMethod(for user: FirebaseAuth.User) -> ParentAuthSignInMethod {
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            return .apple
        }

        return .emailPassword
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randomBytes = (0..<16).map { _ in UInt8.random(in: 0 ... 255) }

            randomBytes.forEach { random in
                if remainingLength == 0 {
                    return
                }

                let randomIndex = Int(random)
                if randomIndex < charset.count {
                    result.append(charset[randomIndex])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var presentationAnchor: ASPresentationAnchor?

    func requestCredential(rawNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        guard let anchor = Self.findPresentationAnchor() else {
            throw ParentAuthProviderError.unavailable
        }

        presentationAnchor = anchor

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(rawNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: ParentAuthProviderError.unknown)
            continuation = nil
            return
        }

        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: Self.mapAppleError(error))
        continuation = nil
    }

    private static func findPresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func mapAppleError(_ error: Error) -> ParentAuthProviderError {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            return .cancelled
        }

        return .unknown
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
#else
final class FirebaseParentAuthProvider: ParentAuthProviding {
    var currentUser: ParentAuthUser? { nil }

    @discardableResult
    func addAuthStateObserver(_ observer: @escaping @MainActor (ParentAuthUser?) -> Void) -> UUID {
        let id = UUID()
        Task { @MainActor in
            observer(nil)
        }
        return id
    }

    func removeAuthStateObserver(id: UUID) {}
    func createUser(email: String, password: String) async throws -> ParentAuthUser {
        throw ParentAuthProviderError.unavailable
    }
    func signIn(email: String, password: String) async throws -> ParentAuthUser {
        throw ParentAuthProviderError.unavailable
    }
    func signInWithApple() async throws -> ParentAuthUser {
        throw ParentAuthProviderError.unavailable
    }
    func signOut() throws {
        throw ParentAuthProviderError.unavailable
    }
}
#endif
