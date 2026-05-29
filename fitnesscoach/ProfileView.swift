//
//  ProfileView.swift
//  fitnesscoach
//

import SwiftUI

struct ProfileView: View {
    @AppStorage("profileName") private var name = ""
    @AppStorage("profileWeight") private var weight = 70.0
    @AppStorage("profileHeight") private var height = 170.0
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal = 500.0
    @AppStorage("totalSquatReps") private var totalSquatReps = 0
    @AppStorage("totalPushupReps") private var totalPushupReps = 0
    @AppStorage("trackedWorkoutCalories") private var trackedWorkoutCalories = 0.0
    @AppStorage("trackedWorkoutDate") private var trackedWorkoutDate = ""
    @StateObject private var healthKitManager = HealthKitManager()

    private var bodyMassIndex: Double {
        let heightInMeters = height / 100
        guard heightInMeters > 0 else { return 0 }
        return weight / (heightInMeters * heightInMeters)
    }

    private var dailyProgress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(totalActiveCalories / dailyCalorieGoal, 1)
    }

    private var cameraCaloriesToday: Double {
        DailyTrackingDate.caloriesForToday(
            trackedWorkoutCalories,
            storedDate: trackedWorkoutDate
        )
    }

    private var totalActiveCalories: Double {
        healthKitManager.activeCalories + cameraCaloriesToday
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $height, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Progress") {
                    ProfileProgressRow(
                        title: "Daily Calories",
                        value: "\(Int(totalActiveCalories)) / \(Int(dailyCalorieGoal)) kcal",
                        progress: dailyProgress,
                        tint: .orange
                    )

                    ProfileMetricRow(
                        title: "Camera Calories",
                        value: "\(Int(cameraCaloriesToday)) kcal"
                    )

                    ProfileMetricRow(
                        title: "Steps Today",
                        value: healthKitManager.stepCount.formatted(.number.precision(.fractionLength(0)))
                    )

                    ProfileMetricRow(
                        title: "BMI",
                        value: bodyMassIndex.formatted(.number.precision(.fractionLength(1)))
                    )

                    ProfileMetricRow(
                        title: "Total Squats",
                        value: totalSquatReps.formatted()
                    )

                    ProfileMetricRow(
                        title: "Total Push Ups",
                        value: totalPushupReps.formatted()
                    )
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshHealthData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh profile progress")
                }
            }
            .task {
                await refreshHealthData()
            }
            .refreshable {
                await refreshHealthData()
            }
        }
    }

    private func refreshHealthData() async {
        await healthKitManager.requestAuthorization()
        await healthKitManager.loadTodayHealthSummary()
    }
}

private struct ProfileProgressRow: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(progress * 100)) percent")
        }
    }
}

private struct ProfileMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
    ProfileView()
    }
}
