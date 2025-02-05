//
//  LoginView.swift
//  TimeTable
//
//  Created by 鍾心哲 on 2025/2/5.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var errorMessage = ""
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var showHowToUse = false
    
    var body: some View {
        ZStack {
            // 背景漸層
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo 和標題
                VStack(spacing: 15) {
                    Image(systemName: "calendar")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("不揪？")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("分享課表 找到共同時間")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 100)
                
                // 輸入表單
                VStack(spacing: 15) {
                    // Email 輸入框
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                            .frame(width: 30)
                        TextField("", text: $email)
                            .placeholder(when: email.isEmpty) {
                                Text("Email").foregroundColor(.gray)
                            }
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    
                    // 密碼輸入框
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                            .frame(width: 30)
                        SecureField("", text: $password)
                            .placeholder(when: password.isEmpty) {
                                Text("密碼").foregroundColor(.gray)
                            }
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    
                    // 名字輸入框（註冊時顯示）
                    if isRegistering {
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(.gray)
                                .frame(width: 30)
                            TextField("", text: $name)
                                .placeholder(when: name.isEmpty) {
                                    Text("名字").foregroundColor(.gray)
                                }
                                .foregroundColor(.black)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                
                // 錯誤訊息
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                // 登入按鈕
                Button(action: { isRegistering ? register() : login() }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        }
                        Text(isRegistering ? "註冊" : "登入")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .disabled(isLoading)
                
                // 註冊和使用說明按鈕
                VStack(spacing: 15) {
                    Button(action: { withAnimation { isRegistering.toggle() } }) {
                        Text(isRegistering ? "已有帳號？登入" : "還沒有帳號？註冊")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showHowToUse.toggle() }) {
                        Text("如何使用？")
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
        }
        .alert("如何使用？", isPresented: $showHowToUse) {
            Button("關閉", role: .cancel) { }
        } message: {
            Text("歡迎來到不揪！這是一個分享課表的APP，你可以在這裡管理自己的課表，也可以查看好友的課表。")
        }
    }
    
    // 登入函數
    private func login() {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            isLoading = false
            if let error = error {
                errorMessage = "登入失敗：\(error.localizedDescription)"
            } else {
                withAnimation {
                    isLoggedIn = true
                }
            }
        }
    }
    
    // 註冊函數
    private func register() {
        guard !name.isEmpty else {
            errorMessage = "請輸入名字"
            return
        }
        
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                isLoading = false
                errorMessage = "註冊失敗：\(error.localizedDescription)"
                return
            }

            guard let user = authResult?.user else {
                isLoading = false
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
                isLoading = false
                if let error = error {
                    errorMessage = "使用者資料儲存失敗：\(error.localizedDescription)"
                } else {
                    withAnimation {
                        isLoggedIn = true
                    }
                }
            }
        }
    }
}
