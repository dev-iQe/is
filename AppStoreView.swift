import SwiftUI
import UniformTypeIdentifiers

struct AppSource: Decodable {
    let name: String?
    let apps: [AppItem]
}

struct AppItem: Identifiable, Decodable {
    var id = UUID()
    let name: String
    let bundleIdentifier: String?
    let subtitle: String?
    let iconURL: String?
    let downloadURL: String
    let version: String?

    enum CodingKeys: String, CodingKey {
        case name, bundleIdentifier, subtitle, iconURL, downloadURL, version
    }
}

struct AppStoreView: View {
    @State private var apps: [AppItem] = []
    @State private var showingCertificateSheet = false
    @State private var showingFileImporter = false
    @State private var statusMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // شريط التنبيهات
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    // قسم رفع ملف IPA محلي
                    VStack(alignment: .leading) {
                        Text("رفع وتوقيع خارجي")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        Button(action: { showingFileImporter = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("اختر ملف IPA من جهازك")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // قائمة تطبيقات المتجر (App Store Grid/List)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("تطبيقات المتجر (GitHub)")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        ForEach(apps) { app in
                            HStack(spacing: 15) {
                                AsyncImage(url: URL(string: app.iconURL ?? "")) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(14)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.name)
                                        .font(.headline)
                                    Text(app.subtitle ?? "الإصدار: \(app.version ?? "-")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    installAndSign(app: app)
                                }) {
                                    Text("تثبيت")
                                        .font(.callout)
                                        .bold()
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                            Divider().padding(.leading, 85)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("المتجر")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCertificateSheet = true }) {
                        Image(systemName: "key.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCertificateSheet) {
                CertificateView()
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item]) { result in
                switch result {
                case .success(let url):
                    let granted = url.startAccessingSecurityScopedResource()
                    processLocalIPA(url: url)
                    if granted { url.stopAccessingSecurityScopedResource() }
                case .failure(let error):
                    statusMessage = "خطأ في اختيار الملف: \(error.localizedDescription)"
                }
            }
            .onAppear(perform: fetchAppsFromGitHub)
        }
    }
    
    func fetchAppsFromGitHub() {
        guard let url = URL(string: "https://raw.githubusercontent.com/AbdTench/SwiftSource/refs/heads/main/My%20Source") else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data else {
                    self.statusMessage = "تعذر تحميل المصدر: \(error?.localizedDescription ?? "")"
                    return
                }
                do {
                    self.apps = try JSONDecoder().decode(AppSource.self, from: data).apps
                } catch {
                    self.statusMessage = "خطأ في قراءة المصدر: \(error)"
                }
            }
        }.resume()
    }

    func installAndSign(app: AppItem) {
        statusMessage = "جاري تحميل وتوقيع \(app.name)..."
        guard let url = URL(string: app.downloadURL) else { return }
        
        IPASigner.shared.downloadAndSign(from: url) { resultPath in
            DispatchQueue.main.async {
                if let path = resultPath {
                    statusMessage = "تم التوقيع بنجاح! جاري التثبيت..."
                    IPASigner.shared.installOTA(ipaURL: path)
                } else {
                    statusMessage = "فشل التوقيع! يرجى التحقق من الشهادة."
                }
            }
        }
    }
    
    func processLocalIPA(url: URL) {
        statusMessage = "جاري توقيع الملف المحلي..."
        IPASigner.shared.signLocalIPA(at: url) { resultPath in
            DispatchQueue.main.async {
                if let path = resultPath {
                    statusMessage = "تم التوقيع! جاري التثبيت..."
                    IPASigner.shared.installOTA(ipaURL: path)
                } else {
                    statusMessage = "فشل توقيع الملف المحلي."
                }
            }
        }
    }
}
