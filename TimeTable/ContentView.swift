import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @Binding var isLoggedIn: Bool

    @AppStorage("isDarkMode") private var isDarkMode = false
    var body: some View {

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
        .padding()
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct AppEntryView: View {
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                ContentView(isLoggedIn: $isLoggedIn)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear(perform: checkLoginStatus)
    }

    private func checkLoginStatus() {
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
        }
    }
}

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var errorMessage = ""
    @State private var showHowToUse = false
    var body: some View {
        VStack {
            Text("登入")
                .font(.largeTitle)
                .padding()

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("名字", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: login) {
                Text("登入")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding()

            Button(action: register) {
                Text("註冊")
                    .foregroundColor(.blue)
                    .padding()
            }
            Button(action: { showHowToUse.toggle() }) {
                Text("如何使用？")
                    
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .alert("如何使用？", isPresented: $showHowToUse) {
            Button("關閉") { }
        } message: {
            Text("歡迎來到不揪！這是一個分享課表的APP，你可以在這裡管理自己的課表，也可以查看好友的課表。\n首次使用的用戶，要先在註冊時填寫名字，以便好友能夠知道你叫什麼。之後再次登入的時候就不需要輸入名字。\n登入後，你可以在「課表」頁面查看自己的課表，也可以在「好友」頁面查看好友的課表。\n如果有任何問題或建議，請DM我的IG: @justin.chung.2547。")
        }
        .padding()
    }

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = "登入失敗：\(error.localizedDescription)"
            } else {
                isLoggedIn = true // 通知外部視圖用戶已登入
            }
        }
    }

    func register() {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = "註冊失敗：\(error.localizedDescription)"
                return
            }

            guard let user = authResult?.user else {
                errorMessage = "註冊失敗：無法取得用戶資訊"
                return
            }

            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": user.email ?? "",
                "name": name,
                "timestamp": Timestamp()
            ]
            
            db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    errorMessage = "使用者資料儲存失敗：\(error.localizedDescription)"
                } else {
                    errorMessage = "註冊成功！"
                }
            }
        }
    }

}

struct TimeTableView: View {
    let days = ["一", "二", "三", "四", "五"]
    let times = (1...10).map { "\($0)" }
    
    @State private var selectedCourses: [[Bool]] = Array(repeating: Array(repeating: false, count: 5), count: 10)
    @State private var saveMessage = ""

    var body: some View {
        VStack {
            HStack {
                Text("")
                    .frame(width: 30) // 空白佔位符對齊課表
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .frame(width: 50)
                }
            }
            ForEach(times.indices, id: \.self) { timeIndex in
                HStack {
                    Text(times[timeIndex])
                        .frame(width: 30)
                    ForEach(days.indices, id: \.self) { dayIndex in
                        Button {
                            selectedCourses[timeIndex][dayIndex].toggle()
                        } label: {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedCourses[timeIndex][dayIndex] ? Color.blue : Color.gray)
                                .frame(width: 50, height: 50)
                        }
                    }
                }
            }

            HStack {
                Button(action: clearTimeTable) {
                    Text("清除課表")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                Button(action: saveTimeTableToFirestore) {
                    Text("儲存課表")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            Spacer()

            // 儲存成功或失敗訊息
            if !saveMessage.isEmpty {
                Text(saveMessage)
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .onAppear(perform: loadTimeTable)
    }

    // 儲存課表到 Firestore
    private func saveTimeTableToFirestore() {
        guard let user = Auth.auth().currentUser else {
            saveMessage = "請先登入"
            return
        }
        let db = Firestore.firestore()
        
        // 將課表轉換為字典格式
        var timetableData: [String: Any] = [:]
        for (rowIndex, row) in selectedCourses.enumerated() {
            timetableData["row_\(rowIndex)"] = row
        }
        
        let dataToSave: [String: Any] = [
            "userId": user.uid,
            "timetable": timetableData,
            "timestamp": Timestamp()
        ]
        
        db.collection("timetables").document(user.uid).setData(dataToSave) { error in
            if let error = error {
                saveMessage = "儲存失敗：\(error.localizedDescription)"
            } else {
                saveMessage = "課表已成功儲存！"
            }
        }
    }


    private func clearTimeTable() {
        // 清除目前選中的課表狀態
        selectedCourses = Array(repeating: Array(repeating: false, count: 5), count: 10)
        
        // 清除本地 UserDefaults 資料
        UserDefaults.standard.removeObject(forKey: "SavedTimeTable")
        print("本地課表已清除")

        // 清除 Firebase Firestore 中的課表
        guard let user = Auth.auth().currentUser else {
            print("未登入用戶，無法清除 Firestore 上的課表")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("timetables").document(user.uid).delete { error in
            if let error = error {
                print("清除 Firestore 課表失敗：\(error.localizedDescription)")
            } else {
                print("Firestore 課表已清除")
            }
        }
    }


    private func loadTimeTable() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()

        db.collection("timetables").document(user.uid).getDocument { document, error in
            if let document = document, document.exists {
                if let timetable = document.data()?["timetable"] as? [String: [Bool]] {
                    // 按行索引排序並轉換回嵌套陣列
                    let sortedKeys = timetable.keys.sorted { $0 < $1 }
                    selectedCourses = sortedKeys.compactMap { timetable[$0] }
                    saveMessage = "課表已載入"
                }
            } else {
                print("無法找到課表：\(error?.localizedDescription ?? "未知錯誤")")
            }
        }
    }

}

struct FriendsTimeTableView: View {
    @State private var friendEmailInput = ""
    @State private var friends: [(uid: String, email: String, name: String)] = []
    @State private var errorMessage = ""
    @State private var availableFriends: [(uid: String, email: String, name: String)] = []
    @State private var busyFriends: [(uid: String, email: String, name: String)] = []
    
    // 添加時間常量
    let startTimes = ["8:10", "9:10", "10:20", "11:20", "12:20", "13:20", "14:20", "15:30", "16:30", "17:30"]
    let endTimes = ["9:00", "10:00", "11:10", "12:10", "13:10", "14:10", "15:10", "16:20", "17:20", "18:20"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("新增好友")) {
                    TextField("輸入好友的 Email", text: $friendEmailInput)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("加好友") {
                        addFriend()
                    }
                    .foregroundColor(.blue)
                }

                // 有空的朋友
                Section(header: Text("現在有空的朋友")) {
                    ForEach(availableFriends, id: \.uid) { friend in
                        NavigationLink(destination: FriendTimeTableView(
                            friendUID: friend.uid,
                            friendEmail: friend.email,
                            friendName: friend.name
                        )) {
                            Text(friend.name)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteFriend(friendUID: friend.uid)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                }
                
                // 沒空的朋友
                Section(header: Text("現在有課的朋友")) {
                    ForEach(busyFriends, id: \.uid) { friend in
                        NavigationLink(destination: FriendTimeTableView(
                            friendUID: friend.uid,
                            friendEmail: friend.email,
                            friendName: friend.name
                        )) {
                            Text(friend.name)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteFriend(friendUID: friend.uid)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("朋友的課表")
            .onAppear(perform: loadFriends)
            .alert("錯誤", isPresented: Binding<Bool>(
                get: { !errorMessage.isEmpty },
                set: { _ in errorMessage = "" }
            )) {
                Button("確定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 判斷當前時間是否在課堂時間內
    private func getCurrentTimeSlot() -> Int? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let currentTimeString = dateFormatter.string(from: Date())
        
        for (index, (start, end)) in zip(startTimes, endTimes).enumerated() {
            if let startTime = dateFormatter.date(from: start),
               let endTime = dateFormatter.date(from: end),
               let currentTime = dateFormatter.date(from: currentTimeString) {
                
                if currentTime >= startTime && currentTime <= endTime {
                    return index
                }
            }
        }
        return nil
    }
    
    // 檢查朋友在當前時段是否有課
    private func checkFriendAvailability(friendUID: String, completion: @escaping (Bool) -> Void) {
        guard let currentTimeSlot = getCurrentTimeSlot() else {
            completion(true) // 如果不在任何時段內，視為有空
            return
        }
        
        let currentDay = Calendar.current.component(.weekday, from: Date())
        let adjustedDay = currentDay == 1 ? 6 : currentDay - 2 // 將週日=1改為週一=0
        
        guard adjustedDay >= 0 && adjustedDay < 5 else {
            completion(true) // 如果是週末，視為有空
            return
        }
        
        let db = Firestore.firestore()
        db.collection("timetables").document(friendUID).getDocument { document, error in
            if let document = document,
               let timetable = document.data()?["timetable"] as? [String: [Bool]],
               let row = timetable["row_\(currentTimeSlot)"] {
                completion(!row[adjustedDay]) // 如果該時段為 false 則表示有空
            } else {
                completion(true) // 如果沒有課表數據，視為有空
            }
        }
    }
    
    // 修改載入好友列表的函數
    private func loadFriends() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "請先登入"
            return
        }
        
        // 重置朋友列表
        availableFriends.removeAll()
        busyFriends.removeAll()
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists {
                if let friendsArray = document.data()?["friends"] as? [[String: String]] {
                    self.friends = friendsArray.compactMap { friendDict in
                        if let uid = friendDict["uid"],
                           let email = friendDict["email"],
                           let name = friendDict["name"] {
                            return (uid: uid, email: email, name: name)
                        }
                        return nil
                    }
                    
                    // 檢查每個朋友的可用性
                    for friend in self.friends {
                        checkFriendAvailability(friendUID: friend.uid) { isAvailable in
                            DispatchQueue.main.async {
                                if isAvailable {
                                    if !self.availableFriends.contains(where: { $0.uid == friend.uid }) {
                                        self.availableFriends.append(friend)
                                    }
                                } else {
                                    if !self.busyFriends.contains(where: { $0.uid == friend.uid }) {
                                        self.busyFriends.append(friend)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if let error = error {
                errorMessage = "載入好友列表失敗：\(error.localizedDescription)"
            }
        }
    }

    // 新增好友到 Firestore
    private func addFriend() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "請先登入"
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        db.collection("users").whereField("email", isEqualTo: friendEmailInput).getDocuments { snapshot, error in
            if let error = error {
                errorMessage = "搜尋用戶失敗：\(error.localizedDescription)"
                return
            }

            guard let document = snapshot?.documents.first else {
                errorMessage = "找不到該用戶"
                return
            }

            let friendUID = document.documentID
            let friendEmail = document.data()["email"] as? String ?? "未知 Email"
            let friendName = document.data()["name"] as? String ?? "未知用戶"

            userRef.updateData([
                "friends": FieldValue.arrayUnion([
                    [
                        "uid": friendUID, 
                        "email": friendEmail,
                        "name": friendName
                    ]
                ])
            ]) { error in
                if let error = error {
                    errorMessage = "新增好友失敗：\(error.localizedDescription)"
                } else {
                    friendEmailInput = ""
                    loadFriends()
                }
            }
        }
    }

    // 刪除好友
    private func deleteFriend(friendUID: String) {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "請先登入"
            return
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        if let friendToRemove = friends.first(where: { $0.uid == friendUID }) {
            userRef.updateData([
                "friends": FieldValue.arrayRemove([
                    [
                        "uid": friendToRemove.uid, 
                        "email": friendToRemove.email,
                        "name": friendToRemove.name
                    ]
                ])
            ]) { error in
                if let error = error {
                    errorMessage = "刪除好友失敗：\(error.localizedDescription)"
                } else {
                    friends.removeAll { $0.uid == friendUID }
                }
            }
        }
    }
}

struct FriendTimeTableView: View {
    let friendUID: String
    let friendEmail: String
    let friendName: String
    
    @State private var timetable: [[Bool]] = Array(repeating: Array(repeating: false, count: 5), count: 10)
    @State private var errorMessage = ""
    
    let days = ["一", "二", "三", "四", "五"]
    let times = (1...10).map { "\($0)" }
    
    // 添加時間常量
    let startTimes = ["8:10", "9:10", "10:20", "11:20", "12:20", "13:20", "14:20", "15:30", "16:30", "17:30"]
    let endTimes = ["9:00", "10:00", "11:10", "12:10", "13:10", "14:10", "15:10", "16:20", "17:20", "18:20"]

    var body: some View {
        VStack {
            Text("\(friendName)的課表")
                .font(.headline)
                .padding()

            if timetable.isEmpty {
                Text("尚未加載課表")
                    .foregroundColor(.gray)
            } else {
                VStack {
                    HStack {
                        Text("")
                            .frame(width: 30)
                        ForEach(days, id: \.self) { day in
                            Text(day)
                                .frame(width: 50)
                        }
                    }
                    ForEach(times.indices, id: \.self) { timeIndex in
                        HStack {
                            Text(times[timeIndex])
                                .frame(width: 30)
                            ForEach(days.indices, id: \.self) { dayIndex in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(getCellColor(timeIndex: timeIndex, dayIndex: dayIndex))
                                    .frame(width: 50, height: 50)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: loadTimetable)
        .alert("錯誤", isPresented: Binding<Bool>(
            get: { !errorMessage.isEmpty },
            set: { _ in errorMessage = "" }
        )) {
            Button("確定") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // 獲取方塊顏色
    private func getCellColor(timeIndex: Int, dayIndex: Int) -> Color {
        // 如果該格子有課
        if timetable[timeIndex][dayIndex] {
            // 檢查是否是當前時間的課
            if isCurrentTimeSlot(timeIndex: timeIndex) && isCurrentDay(dayIndex: dayIndex) {
                return .red  // 當前正在進行的課程顯示為紅色
            }
            return .blue    // 其他課程顯示為藍色
        }
        return .gray       // 沒有課程顯示為灰色
    }
    
    // 檢查是否是當前時間段
    private func isCurrentTimeSlot(timeIndex: Int) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let currentTimeString = dateFormatter.string(from: Date())
        
        guard let currentTime = dateFormatter.date(from: currentTimeString),
              let startTime = dateFormatter.date(from: startTimes[timeIndex]),
              let endTime = dateFormatter.date(from: endTimes[timeIndex]) else {
            return false
        }
        
        return currentTime >= startTime && currentTime <= endTime
    }
    
    // 檢查是否是當前星期
    private func isCurrentDay(dayIndex: Int) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // 將 weekday（1=星期日）轉換為我們的格式（0=星期一）
        let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
        return adjustedWeekday == dayIndex
    }
    
    // 從 Firestore 加載好友課表
    private func loadTimetable() {
        let db = Firestore.firestore()

        db.collection("timetables").document(friendUID).getDocument { document, error in
            if let document = document, document.exists {
                if let rawTimetable = document.data()?["timetable"] as? [String: [Bool]] {
                    // 將 Firebase 返回的字典數據轉換為陣列
                    let sortedKeys = rawTimetable.keys.sorted { $0 < $1 }
                    timetable = sortedKeys.compactMap { rawTimetable[$0] }
                } else {
                    errorMessage = "無法解析課表數據"
                }
            } else if let error = error {
                errorMessage = "無法加載課表：\(error.localizedDescription)"
            } else {
                errorMessage = "課表不存在"
            }
        }
    }
}

// 新增開發者介紹視圖
struct DeveloperInfoView: View {
    var body: some View {
        List {
            Section("About me") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hi, I’m Justin, a freshman at National Taiwan University majoring in Information Management.")
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

// 修改 SettingsView
struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Binding var isLoggedIn: Bool
    @State private var userEmail: String = ""
    @State private var userName: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("帳號資訊") {
                    HStack {
                        Text("名稱")
                        Spacer()
                        Text(userName)
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(userEmail)
                            .foregroundColor(.gray)
                    }
                }
                
                Section("帳號") {
                    Button("登出") {
                        do {
                            try Auth.auth().signOut()
                            isLoggedIn = false
                        } catch {
                            print("登出失敗：\(error.localizedDescription)")
                        }
                    }
                }
                
                Section("介面設定") {
                    HStack {
                        Toggle(isOn: $isDarkMode) {
                            Text("深色模式")
                        }
                    }
                }
                
                // 新增開發者資訊連結
                Section("其他") {
                    NavigationLink(destination: DeveloperInfoView()) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("About me")
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .background(isDarkMode ? Color.black : Color.white)
            .animation(.easeInOut, value: isDarkMode)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onAppear {
                loadUserInfo()
            }
        }
    }
    
    private func loadUserInfo() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists {
                userName = document.data()?["name"] as? String ?? "未知用戶"
                userEmail = document.data()?["email"] as? String ?? "未知 Email"
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
}

