import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @Binding var isLoggedIn: Bool

    @AppStorage("isDarkMode") private var isDarkMode = false
    var body: some View {
        VStack {
            TabView {
                TimeTableView().tabItem {
                    NavigationLink(destination: TimeTableView()) {
                        Image(systemName: "calendar")
                        Text("Timetable")
                    }
                    .tag(1)
                }
                FriendsTimeTableView().tabItem {
                    NavigationLink(destination: FriendsTimeTableView()) {
                        Image(systemName: "person.circle")
                        Text("Friends")
                    }
                    .tag(2)
                }
                SettingsView(isLoggedIn: $isLoggedIn).tabItem {
                    NavigationLink(destination: SettingsView(isLoggedIn: $isLoggedIn)) {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// 新增開發者介紹視圖
struct DeveloperInfoView: View {
    var body: some View {
        List {
            Section("About me") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hi, I'm Justin, a freshman at National Taiwan University majoring in Information Management.")
                    Text("If you'd like to contact me or report any bugs, feel free to DM me on Instagram or send me an email.")
                }
                .padding(.vertical, 8)
            }
            
            Section("About the APP") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("不揪？")
                        .font(.headline)
                    
                    Text("版本：1.0.0")
                    Text("這是一個幫助學生管理和分享課表的應用程式。")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
            
            Section("Contact") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Email：hi1214justin@gmail.com")
                    Link("Instragram", destination: URL(string: "https://www.instagram.com/justin.chung.2547?igsh=MWswdDhoZzRqZ2NsNg%3D%3D&utm_source=qr")!)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("About me")
    }
}

// 添加 placeholder 擴展
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// 添加十六進制顏色擴展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    TimeTableView()
}
