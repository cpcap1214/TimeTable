//
//  AppEntryView.swift
//  TimeTable
//
//  Created by 鍾心哲 on 2025/2/5.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
