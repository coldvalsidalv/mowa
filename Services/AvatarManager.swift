import SwiftUI
import Combine

final class AvatarManager: ObservableObject {
    static let shared = AvatarManager()
    
    @Published var avatar: UIImage?
    
    private let filename = "user_avatar.jpg"
    private var avatarURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    private let ioQueue = DispatchQueue(label: "com.mowa.avatarIO", qos: .userInitiated)
    
    private init() {
        loadAvatar()
    }
    
    func loadAvatar() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            if FileManager.default.fileExists(atPath: self.avatarURL.path),
               let image = UIImage(contentsOfFile: self.avatarURL.path) {
                DispatchQueue.main.async {
                    self.avatar = image
                }
            }
        }
    }
    
    func saveAvatar(_ data: Data) {
        ioQueue.async { [weak self] in
            guard let self = self,
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
            
            do {
                try jpegData.write(to: self.avatarURL, options: .atomic)
                DispatchQueue.main.async {
                    self.avatar = UIImage(data: jpegData)
                }
            } catch {
                print("Ошибка сохранения аватара: \(error)")
            }
        }
    }
    
    func deleteAvatar() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.avatarURL)
            DispatchQueue.main.async {
                self.avatar = nil
            }
        }
    }
}
