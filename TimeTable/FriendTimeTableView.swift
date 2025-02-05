//
//  FriendTimeTableView.swift
//  TimeTable
//
//  Created by 鍾心哲 on 2025/2/5.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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

    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
                            RoundedRectangle(cornerRadius: 10)
                                .fill(getCellColor(timeIndex: timeIndex, dayIndex: dayIndex))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: getCellColor(timeIndex: timeIndex, dayIndex: dayIndex).opacity(0.3),
                                        radius: timetable[timeIndex][dayIndex] ? 4 : 0)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(friendName)的課表")
        .alert("錯誤", isPresented: Binding<Bool>(
            get: { !errorMessage.isEmpty },
            set: { _ in errorMessage = "" }
        )) {
            Button("確定") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear(perform: loadTimetable)
    }
    
    // 更新顏色函數
    private func getCellColor(timeIndex: Int, dayIndex: Int) -> Color {
        if isCurrentTimeSlot(timeIndex: timeIndex) && isCurrentDay(dayIndex: dayIndex) {
            return timetable[timeIndex][dayIndex] ? .red : .red.opacity(0.3)
        }
        if timetable[timeIndex][dayIndex] {
            return .blue.opacity(0.8)
        }
        return colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
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
