import Foundation
import ZIPFoundation
import UIKit

class IPASigner {
    static let shared = IPASigner()

    func downloadAndSign(from url: URL, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            guard let localURL = localURL else { completion(nil); return }
            self.signLocalIPA(at: localURL, completion: completion)
        }
        task.resume()
    }

    func signLocalIPA(at ipaURL: URL, completion: @escaping (URL?) -> Void) {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let p12Path = docs.appendingPathComponent("cert.p12").path
        let provPath = docs.appendingPathComponent("cert.mobileprovision").path

        guard fileManager.fileExists(atPath: p12Path), fileManager.fileExists(atPath: provPath) else {
            print("الشهادات غير مكتملة")
            completion(nil)
            return
        }

        let workDir = docs.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)

        do {
            try fileManager.unzipItem(at: ipaURL, to: workDir)
            let signedIPAPath = docs.appendingPathComponent("signed_app.ipa")

            // TODO: التوقيع الفعلي (zsign) يوضع هنا قبل إعادة الضغط

            try? fileManager.removeItem(at: signedIPAPath)
            try fileManager.zipItem(at: workDir, to: signedIPAPath, shouldKeepParent: false)
            try? fileManager.removeItem(at: workDir)
            completion(signedIPAPath)
        } catch {
            print("خطأ أثناء معالجة الـ IPA: \(error)")
            completion(nil)
        }
    }

    /// تثبيت عبر itms-services (يحتاج سيرفر HTTPS حقيقي)
    func installOTA(ipaURL: URL) {
        let plistURL = "itms-services://?action=download-manifest&url=https://yourserver.com/manifest.plist"
        if let url = URL(string: plistURL) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
