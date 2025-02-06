//
//  FriendsTimeTableView.swift
//  TimeTable
//
//  Created by 鍾心哲 on 2025/2/5.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendsTimeTableView: View {
    @State private var friendEmailInput = ""
    @State private var friends: [(uid: String, email: String, name: String)] = []
    @State private var errorMessage = ""
    @State private var availableFriends: [(uid: String, email: String, name: String)] = []
    @State private var busyFriends: [(uid: String, email: String, name: String)] = []
    @State private var showUsageInstructions = false
    
    // 添加時間常量
    let startTimes = ["8:10", "9:10", "10:20", "11:20", "12:20", "13:20", "14:20", "15:30", "16:30", "17:30"]
    let endTimes = ["9:00", "10:00", "11:10", "12:10", "13:10", "14:10", "15:10", "16:20", "17:20", "18:20"]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("新增好友").foregroundColor(.blue)) {
                    HStack {
                        Image(systemName: "person.fill.badge.plus")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                        TextField("輸入好友的 Email", text: $friendEmailInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    Button(action: addFriend) {
                        HStack {
                            Spacer()
                            Text("加好友")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.vertical, 5)
                }

                // 有空的朋友
                Section(header: 
                    HStack {
                        Image(systemName: "person.fill.checkmark")
                            .foregroundColor(.green)
                        Text("現在有空的朋友")
                            .foregroundColor(.green)
                    }
                ) {
                    if availableFriends.isEmpty {
                        Text("現在有課的朋友")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(availableFriends, id: \.uid) { friend in
                            NavigationLink(destination: FriendTimeTableView(
                                friendUID: friend.uid,
                                friendEmail: friend.email,
                                friendName: friend.name
                            )) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 30))
                                    VStack(alignment: .leading) {
                                        Text(friend.name)
                                            .font(.headline)
                                        Text(friend.email)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
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
                
                // 沒空的朋友
                Section(header: 
                    HStack {
                        Image(systemName: "person.fill.xmark")
                            .foregroundColor(.red)
                        Text("現在有課的朋友")
                            .foregroundColor(.red)
                    }
                ) {
                    if busyFriends.isEmpty {
                        Text("目前沒有正在上課的朋友")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(busyFriends, id: \.uid) { friend in
                            NavigationLink(destination: FriendTimeTableView(
                                friendUID: friend.uid,
                                friendEmail: friend.email,
                                friendName: friend.name
                            )) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 30))
                                    VStack(alignment: .leading) {
                                        Text(friend.name)
                                            .font(.headline)
                                        Text(friend.email)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
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
            }
            .listStyle(InsetGroupedListStyle())
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showUsageInstructions.toggle()
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .alert("使用說明", isPresented: $showUsageInstructions) {
                Button("關閉", role: .cancel) { }
            } message: {
                Text("在這裡你可以查看好友的課表，並查看他們是否有空。\n點擊好友名稱以查看詳細課表，或滑動以刪除好友。")
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
