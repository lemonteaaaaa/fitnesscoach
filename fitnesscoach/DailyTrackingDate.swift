//
//  DailyTrackingDate.swift
//  fitnesscoach
//

import Foundation

enum DailyTrackingDate {
    static var todayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }

    static func caloriesForToday(_ calories: Double, storedDate: String) -> Double {
        storedDate == todayKey ? calories : 0
    }
}
