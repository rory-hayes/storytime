import SwiftUI

struct ParentAccountSheetView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case createAccount
        case signIn

        var id: String { rawValue }

        var title: String {
            switch self {
            case .createAccount:
                return "Create Account"
            case .signIn:
                return "Sign In"
            }
        }

        var primaryButtonTitle: String {
            switch self {
            case .createAccount:
                return "Create Parent Account"
            case .signIn:
                return "Sign In"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var parentAuthManager: ParentAuthManager

    @State private var mode: Mode
    @State private var email = ""
    @State private var password = ""

    init(initialMode: Mode = .createAccount) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        Form {
            Section {
                Text("Parent account")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .accessibilityIdentifier("parentAccountSheetTitle")

                Text(sheetSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentAccountSheetSummary")
            }

            if parentAuthManager.isSignedIn {
                Section {
                    Text(signedInSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountSheetSignedInSummary")

                    Text("Signing out removes the parent account session from this device only. Child story history still stays local on device in this sprint.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountSheetSignOutSummary")
                }

                Section {
                    Button("Sign Out on This Device", role: .destructive) {
                        if parentAuthManager.signOut() {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("parentAccountSheetSignOutButton")

                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("parentAccountCancelButton")
                }
            } else {
                Section {
                    Picker("Account action", selection: $mode) {
                        ForEach(Mode.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("parentAccountModePicker")

                    TextField("Parent email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .accessibilityIdentifier("parentAccountEmailField")

                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("parentAccountPasswordField")

                    Text("Once a parent signs in, Firebase Auth keeps that account session available on this device after relaunch until a parent signs out. Saved child story history still stays local on device in this sprint.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountPersistenceFootnote")

                    Button {
                        Task {
                            let succeeded = await parentAuthManager.signInWithApple()
                            if succeeded {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                            Text("Sign In with Apple")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.black)
                        )
                    }
                    .disabled(parentAuthManager.isPerformingAccountAction)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parentAccountAppleButton")

                    Text("Sign in with Apple stays parent-managed here and keeps the signed-in parent session available on this device after relaunch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountAppleSummary")

                    if let authErrorMessage = parentAuthManager.authErrorMessage {
                        Text(authErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("parentAccountErrorMessage")
                    }
                }

                Section {
                    Button(mode.primaryButtonTitle) {
                        Task {
                            let succeeded: Bool
                            switch mode {
                            case .createAccount:
                                succeeded = await parentAuthManager.createAccount(email: email, password: password)
                            case .signIn:
                                succeeded = await parentAuthManager.signIn(email: email, password: password)
                            }

                            if succeeded {
                                dismiss()
                            }
                        }
                    }
                    .disabled(parentAuthManager.isPerformingAccountAction || trimmedEmail.isEmpty || password.isEmpty)
                    .accessibilityIdentifier("parentAccountPrimaryButton")

                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .accessibilityIdentifier("parentAccountCancelButton")
                }
            }
        }
        .navigationTitle("Parent Account")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(parentAuthManager.isPerformingAccountAction)
        .onChange(of: mode) {
            parentAuthManager.clearAuthError()
        }
        .onDisappear {
            parentAuthManager.clearAuthError()
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sheetSummary: String {
        if parentAuthManager.isSignedIn {
            return "This account is already signed in on this device. Parents can sign out here without adding auth friction to child story flow."
        }

        return "Create or sign into a parent account here with email/password or Sign in with Apple. Story start stays available without sign-in, but purchase, restore, and promo work remain parent-managed."
    }

    private var signedInSummaryText: String {
        guard let currentUser = parentAuthManager.currentUser else {
            return "Signed in on this device."
        }

        if let email = currentUser.email {
            return "Signed in as \(email)."
        }

        switch currentUser.signInMethod {
        case .apple:
            return "Signed in with Apple on this device."
        case .emailPassword:
            return "Signed in as this parent account."
        }
    }
}
