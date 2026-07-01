import SwiftUI

struct AuthView: View {
    @ObservedObject private var auth = AuthManager.shared

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
                    Text("Войти").tag(Mode.signIn)
                    Text("Регистрация").tag(Mode.signUp)
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
                    .padding(.bottom, 48)
                    .disabled(isSubmitting || !isFormValid)
                    .opacity(isSubmitting || !isFormValid ? 0.6 : 1.0)
                    .overlay(
                        Group {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                        }
                    )
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

            Text(mode == .signIn ? "С возвращением" : "Создай аккаунт")
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .padding(.top, 64)
    }

    private var form: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                TextField("Имя (необязательно)", text: $name)
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

            SecureField("Пароль (минимум 8 символов)", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }
                .modifier(AuthFieldStyle())
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Logic

    private var submitTitle: String {
        mode == .signIn ? "Войти" : "Зарегистрироваться"
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
                // On success RootView re-renders via isAuthenticated, no need to trigger anything.
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Что-то пошло не так: \(error.localizedDescription)"
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
