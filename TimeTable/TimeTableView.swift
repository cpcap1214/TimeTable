//
//  TimeTableView.swift
//  TimeTable
//
//  Created by 鍾心哲 on 2025/2/5.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore


struct TimeTableView: View {
    let days = ["一", "二", "三", "四", "五"]
    let times = (1...10).map { "\($0)" }
    
    @State private var selectedCourses: [[Bool]] = Array(repeating: Array(repeating: false, count: 5), count: 10)
    @State private var saveMessage = ""
    @State private var showUsageInstructions = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 添加時間常量
    let startTimes = ["8:10", "9:10", "10:20", "11:20", "12:20", "13:20", "14:20", "15:30", "16:30", "17:30"]
    let endTimes = ["9:00", "10:00", "11:10", "12:10", "13:10", "14:10", "15:10", "16:20", "17:20", "18:20"]
    
    // 添加新的狀態變量
    @Environment(\.colorScheme) var colorScheme
    @State private var isSaving = false
    @AppStorage("selectedCourseColorHex") private var selectedCourseColorHex = "3B82F6"  // 蓝色
    @AppStorage("currentTimeColorHex") private var currentTimeColorHex = "EF4444"  // 红色
    @State private var showingColorPicker = false
    
    // 添加计算属性
    private var selectedCourseColor: Color {
        Color(hex: selectedCourseColorHex).opacity(0.8)
    }

    private var currentTimeColor: Color {
        Color(hex: currentTimeColorHex)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    // 星期列
                    HStack {
                        Text("")
                            .frame(width: 40)
                        ForEach(days, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 60)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // 課表格子
                    ForEach(times.indices, id: \.self) { timeIndex in
                        HStack {
                            VStack(spacing: 2) {
                                Text(times[timeIndex])
                                    .font(.system(size: 14, weight: .medium))
                                Text(startTimes[timeIndex])
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40)
                            
                            ForEach(days.indices, id: \.self) { dayIndex in
                                Button {
                                    selectedCourses[timeIndex][dayIndex].toggle()
                                } label: {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(getCellColor(timeIndex: timeIndex, dayIndex: dayIndex))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                        .shadow(color: getCellColor(timeIndex: timeIndex, dayIndex: dayIndex).opacity(0.3),
                                                radius: selectedCourses[timeIndex][dayIndex] ? 4 : 0)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 修改按鈕組
                    HStack(spacing: 20) {
                        Button(action: clearTimeTable) {
                            HStack {
                                Image(systemName: "trash")
                                Text("清除課表")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red)
                                    .shadow(radius: 3)
                            )
                        }
                        .disabled(isSaving)
                        
                        Button(action: saveTimeTableToFirestore) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("儲存課表")
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                                    .shadow(radius: 3)
                            )
                        }
                        .disabled(isSaving)
                    }
                    .padding(.top, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("課表")
            .alert("提示", isPresented: $showAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadTimeTable()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showUsageInstructions.toggle()
                        }) {
                            Image(systemName: "questionmark.circle")
                        }
                        
                        Button(action: {
                            showingColorPicker.toggle()
                        }) {
                            Image(systemName: "paintpalette")
                        }
                    }
                }
            }
            .alert("使用說明", isPresented: $showUsageInstructions) {
                Button("關閉", role: .cancel) { }
            } message: {
                Text("點擊方塊以選擇課程，點擊已選中的方塊以取消選擇。\n選擇完所有的課程後，請按下方的「儲存課表」按鈕。\n若想要清除課表，請按下方的「清除課表」按鈕。")
            }
            .sheet(isPresented: $showingColorPicker) {
                NavigationView {
                    List {
                        Section("課程顏色") {
                            ColorPicker("選擇課程顏色", selection: Binding(
                                get: { Color(hex: selectedCourseColorHex) },
                                set: { newColor in
                                    if let components = newColor.cgColor?.components,
                                       components.count >= 3 {
                                        let r = Int(components[0] * 255)
                                        let g = Int(components[1] * 255)
                                        let b = Int(components[2] * 255)
                                        selectedCourseColorHex = String(format: "%02X%02X%02X", r, g, b)
                                    }
                                }
                            ))
                            .padding(.vertical, 8)
                        }
                        
                        Section("當前時間顏色") {
                            ColorPicker("選擇當前時間顏色", selection: Binding(
                                get: { Color(hex: currentTimeColorHex) },
                                set: { newColor in
                                    if let components = newColor.cgColor?.components,
                                       components.count >= 3 {
                                        let r = Int(components[0] * 255)
                                        let g = Int(components[1] * 255)
                                        let b = Int(components[2] * 255)
                                        currentTimeColorHex = String(format: "%02X%02X%02X", r, g, b)
                                    }
                                }
                            ))
                            .padding(.vertical, 8)
                        }
                    }
                    .navigationTitle("顏色設定")
                    .navigationBarItems(trailing: Button("完成") {
                        showingColorPicker = false
                    })
                }
            }
        }
    }

    
    // 修改儲存函數
    private func saveTimeTableToFirestore() {
        guard let user = Auth.auth().currentUser else {
            alertMessage = "請先登入"
            showAlert = true
            return
        }
        
        withAnimation {
            isSaving = true
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
            DispatchQueue.main.async {
                withAnimation {
                    isSaving = false
                }
                
                if let error = error {
                    alertMessage = "儲存失敗：\(error.localizedDescription)"
                } else {
                    alertMessage = "課表已成功儲存！"
                }
                showAlert = true
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
                    let sortedKeys = timetable.keys.sorted { $0 < $1 }
                    selectedCourses = sortedKeys.compactMap { timetable[$0] }
                }
            } else {
                print("無法找到課表：\(error?.localizedDescription ?? "未知錯誤")")
            }
        }
    }

    // 更新顏色函數
    private func getCellColor(timeIndex: Int, dayIndex: Int) -> Color {
        if isCurrentTimeSlot(timeIndex: timeIndex) && isCurrentDay(dayIndex: dayIndex) {
            return selectedCourses[timeIndex][dayIndex] ? currentTimeColor : currentTimeColor.opacity(0.3)
        }
        if selectedCourses[timeIndex][dayIndex] {
            return selectedCourseColor
        }
        return colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }
    
    // 新增檢查是否是當前時間段的函數
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
    
    // 新增檢查是否是當前星期的函數
    private func isCurrentDay(dayIndex: Int) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // 將 weekday（1=星期日）轉換為我們的格式（0=星期一）
        let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
        return adjustedWeekday == dayIndex
    }
}
