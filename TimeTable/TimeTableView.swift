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

    // 添加時間常量
    let startTimes = ["8:10", "9:10", "10:20", "11:20", "12:20", "13:20", "14:20", "15:30", "16:30", "17:30"]
    let endTimes = ["9:00", "10:00", "11:10", "12:10", "13:10", "14:10", "15:10", "16:20", "17:20", "18:20"]
    
    var body: some View {
        NavigationView {
            ScrollView {
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
                                        .fill(getCellColor(timeIndex: timeIndex, dayIndex: dayIndex))
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
            }
            .onAppear(perform: loadTimeTable)
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
                Text("點擊方塊以選擇課程，點擊已選中的方塊以取消選擇。\n選擇完所有的課程後，請按下方的「儲存課表」按鈕。\n若想要清除課表，請按下方的「清除課表」按鈕。")
            }
        }
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

    // 新增獲取方塊顏色的函數
    private func getCellColor(timeIndex: Int, dayIndex: Int) -> Color {
        if isCurrentTimeSlot(timeIndex: timeIndex) && isCurrentDay(dayIndex: dayIndex) {
            return .red  // 當前時間段顯示為紅色，無論是否有課
        }
        if selectedCourses[timeIndex][dayIndex] {
            return .blue    // 其他有課的時段顯示為藍色
        }
        return .gray       // 沒有課程顯示為灰色
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
