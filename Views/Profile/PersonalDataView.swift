import SwiftUI
import PhotosUI

struct PersonalDataView: View {
    @AppStorage(StorageKeys.userName) private var userName: String = ""
    @AppStorage(StorageKeys.userEmail) private var userEmail: String = ""
    
    @ObservedObject private var avatarManager = AvatarManager.shared
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            AvatarView(
                                localImage: avatarManager.avatar,
                                name: userName,
                                color: .blue,
                                size: 100
                            )
                            Image(systemName: "camera.fill")
                                .font(.headline).foregroundColor(.white)
                                .padding(8).background(Color.blue).clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .offset(x: 35, y: 35)
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                AvatarManager.shared.saveAvatar(data)
                            }
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            Section(L("personal.basic")) {
                TextField(L("personal.name"), text: $userName)
                TextField("Email", text: $userEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            Section(L("personal.security")) {
                NavigationLink(L("personal.change_password")) { Text(L("personal.in_development")) }
            }

            Section(L("personal.sync")) {
                Toggle(isOn: .constant(true)) { Label("iCloud Sync", systemImage: "icloud.fill") }
                Toggle(isOn: .constant(false)) { Label("Google Sync", systemImage: "g.circle.fill") }
            }
        }
        .navigationTitle(L("profile.personal_data"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
