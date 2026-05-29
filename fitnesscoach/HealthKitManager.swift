//
//  HealthKitManager.swift
//  fitnesscoach
//
//  Created by Faroz Syakir on 08/05/26.
//

import Foundation
import HealthKit
import Combine
import SwiftUI

final class HealthKitManager: ObservableObject {
    @Published var activeCalories = 0.0
    @Published var stepCount = 0.0
    @Published var authorizationStatus: HealthAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            errorMessage = "Health data is not available on this device."
            return
        }

        guard
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            authorizationStatus = .unavailable
            errorMessage = "Active energy or step count data is not available."
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [activeEnergyType, stepCountType])
            authorizationStatus = .authorized
            errorMessage = nil
        } catch {
            authorizationStatus = .denied
            errorMessage = error.localizedDescription
        }
    }

    func loadTodayHealthSummary() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        guard
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            authorizationStatus = .unavailable
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        do {
            let calories = try await totalQuantity(
                for: activeEnergyType,
                predicate: predicate,
                unit: .kilocalorie()
            )
            let steps = try await totalQuantity(
                for: stepCountType,
                predicate: predicate,
                unit: .count()
            )
            activeCalories = calories
            stepCount = steps
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func totalQuantity(
        for quantityType: HKQuantityType,
        predicate: NSPredicate,
        unit: HKUnit
    ) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let total = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }

            healthStore.execute(query)
        }
    }
}

enum HealthAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable

    var message: String {
        switch self {
        case .notDetermined:
            "Ready to connect Health data"
        case .authorized:
            "Reading active calories and steps from Apple Health"
        case .denied:
            "Health access needs permission"
        case .unavailable:
            "Health data is unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .notDetermined:
            "heart.text.square"
        case .authorized:
            "checkmark.seal.fill"
        case .denied:
            "exclamationmark.triangle.fill"
        case .unavailable:
            "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .notDetermined:
            .blue
        case .authorized:
            .green
        case .denied:
            .red
        case .unavailable:
            .gray
        }
    }
}
