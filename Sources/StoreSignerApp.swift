import SwiftUI

@main
struct StoreSignerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                StoreView()
                    .tabItem { Label("المتجر", systemImage: "square.stack.3d.up.fill") }
                SignView()
                    .tabItem { Label("التوقيع", systemImage: "square.and.arrow.up.fill") }
                CertificateView()
                    .tabItem { Label("الشهادات", systemImage: "key.fill") }
            }
        }
    }
}
