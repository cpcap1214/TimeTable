//
//  SettingsView.swift
//  TimeTable
//
//  Created by 鍾心哲 on 2025/2/5.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Binding var isLoggedIn: Bool
    @State private var userEmail: String = ""
    @State private var userName: String = ""
    @State private var showDeleteConfirmation = false

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
                    
                    Button("刪除帳號") {
                        showDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
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
            .alert("確認刪除帳號", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("刪除", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("您確定要刪除帳號嗎？這將無法恢復。")
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
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        let userId = user.uid
        
        // 刪除 Firestore 中的用戶資料
        db.collection("users").document(userId).delete { error in
            if let error = error {
                print("刪除用戶資料失敗：\(error.localizedDescription)")
                return
            }
            
            // 刪除用戶的課表
            db.collection("timetables").document(userId).delete { error in
                if let error = error {
                    print("刪除課表失敗：\(error.localizedDescription)")
                }
            }
            
            // 刪除用戶在其他好友中的資料
            db.collection("users").whereField("friends.uid", isEqualTo: userId).getDocuments { snapshot, error in
                if let error = error {
                    print("查詢好友失敗：\(error.localizedDescription)")
                    return
                }
                
                for document in snapshot!.documents {
                    let friendRef = db.collection("users").document(document.documentID)
                    friendRef.updateData([
                        "friends": FieldValue.arrayRemove([["uid": userId]])
                    ]) { error in
                        if let error = error {
                            print("刪除好友資料失敗：\(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // 刪除 Firebase 認證中的用戶
            user.delete { error in
                if let error = error {
                    print("刪除帳號失敗：\(error.localizedDescription)")
                } else {
                    print("帳號已成功刪除")
                    isLoggedIn = false // 登出
                }
            }
        }
    }
}
