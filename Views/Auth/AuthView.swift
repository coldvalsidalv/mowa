import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject private var auth = AuthManager.shared
    @Environment(\.colorScheme) private var colorScheme

    enum Mode: Hashable { case signIn, signUp }
    @State private var mode: Mode = .signIn

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @FocusState private var focus: Field?
    enum Field { case email, password, name }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Picker("", selection: $mode) {
                    Text(L("auth.sign_in")).tag(Mode.signIn)
                    Text(L("auth.tab_signup")).tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .onChange(of: mode) { _, _ in errorMessage = nil }

                form
                    .padding(.top, 24)

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                }

                OnboardingPrimaryButton(title: submitTitle, action: submit)
                    .padding(.horizontal, 32)
                    .disabled(isSubmitting || !isFormValid)
                    .opacity(isSubmitting || !isFormValid ? 0.6 : 1.0)
                    .overlay(
                        Group {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                        }
                    )

                socialButtons
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

            Text(mode == .signIn ? L("auth.welcome_back") : L("auth.create_account"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .padding(.top, 64)
    }

    private var form: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                TextField(L("auth.name_placeholder"), text: $name)
                    .textContentType(.name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
                    .modifier(AuthFieldStyle())
            }

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
                .modifier(AuthFieldStyle())

            SecureField(L("auth.password_placeholder"), text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }
                .modifier(AuthFieldStyle())
        }
        .padding(.horizontal, 32)
    }

    private var socialButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
                Text(L("auth.or"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5)
            }
            .padding(.bottom, 6)

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if VerbumConfig.isGoogleSignInConfigured {
                Button(action: signInWithGoogle) {
                    HStack(spacing: 8) {
                        Text("G")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        Text(L("auth.continue_google"))
                            .font(.system(size: 17, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.primary)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(UIColor.separator), lineWidth: 0.5)
                    )
                }
            }
        }
        .disabled(isSubmitting)
    }

    // MARK: - Logic

    private var submitTitle: String {
        mode == .signIn ? L("auth.sign_in") : L("auth.btn_signup")
    }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        focus = nil

        Task {
            do {
                switch mode {
                case .signIn:
                    try await auth.signIn(email: email, password: password)
                case .signUp:
                    try await auth.signUp(email: email, password: password,
                                          name: name.isEmpty ? nil : name)
                }
                // При успехе RootView перерисуется по isAuthenticated, дёргать ничего не надо.
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = L("error.unknown", error.localizedDescription)
            }
            isSubmitting = false
        }
    }

    // MARK: - Social sign-in

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = L("error.apple_signin")
                return
            }
            submitExternal(idToken: idToken)
        case .failure(let error):
            // User closed the Apple sheet — not an error.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = L("error.apple_signin")
        }
    }

    private func signInWithGoogle() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        focus = nil

        Task {
            do {
                let idToken = try await GoogleSignInService.shared.signIn()
                try await auth.signIn(externalIdToken: idToken)
            } catch GoogleSignInError.cancelled {
                // silent
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch let error as GoogleSignInError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = L("error.unknown", error.localizedDescription)
            }
            isSubmitting = false
        }
    }

    private func submitExternal(idToken: String) {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        focus = nil

        Task {
            do {
                try await auth.signIn(externalIdToken: idToken)
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = L("error.unknown", error.localizedDescription)
            }
            isSubmitting = false
        }
    }
}

// MARK: - Field style

private struct AuthFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
    }
}

#Preview {
    AuthView()
}
