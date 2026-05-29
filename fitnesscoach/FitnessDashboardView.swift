//
//  FitnessDashboardView.swift
//  fitnesscoach
//
//  Created by Faroz Syakir on 08/05/26.
//

import SwiftUI
import Combine

struct DailyStats: Codable {
    let calories: Double
    let steps: Double
    let date: String
}

struct FitnessDashboardView: View {
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal = 500.0
    @AppStorage("trackedWorkoutCalories") private var trackedWorkoutCalories = 0.0
    @AppStorage("trackedWorkoutDate") private var trackedWorkoutDate = ""

    @AppStorage("dailyStatsHistory") private var dailyStatsHistoryData: Data = Data()

    @State private var selectedDate: Date = Date()

    private var selectedDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    private func loadStats(for dateKey: String) -> DailyStats? {
        guard let decoded = try? JSONDecoder().decode([String: DailyStats].self, from: dailyStatsHistoryData) else {
            return nil
        }
        return decoded[dateKey]
    }

    private func saveStats(_ stats: DailyStats) {
        var currentStats: [String: DailyStats]
        if let decoded = try? JSONDecoder().decode([String: DailyStats].self, from: dailyStatsHistoryData) {
            currentStats = decoded
        } else {
            currentStats = [:]
        }
        currentStats[stats.date] = stats

        if let encoded = try? JSONEncoder().encode(currentStats) {
            dailyStatsHistoryData = encoded
        }
        // TODO: Integrate stats saving where workout/activity data changes
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DatePicker("Tanggal", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Fitness Coach")
                            .font(.largeTitle.bold())
                    }

                    let stats = loadStats(for: selectedDateKey) ?? DailyStats(calories: 0, steps: 0, date: selectedDateKey)
                    let activeCalories = stats.calories
                    let stepCount = stats.steps
                    let remainingCalories = max(dailyCalorieGoal - activeCalories, 0)
                    let progress = dailyCalorieGoal > 0 ? activeCalories / dailyCalorieGoal : 0
                    let progressPercentage = Int((progress * 100).rounded())

                    CalorieProgressCard(
                        activeCalories: activeCalories,
                        cameraCalories: trackedWorkoutCalories,
                        dailyCalorieGoal: dailyCalorieGoal,
                        remainingCalories: remainingCalories,
                        progress: progress,
                        progressPercentage: progressPercentage
                    )

                    StepCountCard(stepCount: stepCount)

                    GoalEditorCard(dailyCalorieGoal: $dailyCalorieGoal)

                    NavigationLink {
                        WorkoutRecommendationsDetailView(recommendations: WorkoutRecommendation.recommendations(progress: progress, remainingCalories: remainingCalories))
                    } label: {
                        RecommendationEntryCard(
                            recommendationCount: WorkoutRecommendation.recommendations(progress: progress, remainingCalories: remainingCalories).count,
                            progressPercentage: progressPercentage
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct WorkoutRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let duration: Int
    let estimatedCalories: Int
    let intensity: String
    let symbolName: String
    let tint: Color

    static func recommendations(progress: Double, remainingCalories: Double) -> [WorkoutRecommendation] {
        if progress >= 1 {
            return [
                WorkoutRecommendation(
                    title: "Recovery Walk",
                    subtitle: "Keep moving without overloading your body.",
                    duration: 20,
                    estimatedCalories: 80,
                    intensity: "Easy",
                    symbolName: "figure.walk",
                    tint: .green
                ),
                WorkoutRecommendation(
                    title: "Mobility Flow",
                    subtitle: "Stretch hips, shoulders, and back after hitting your goal.",
                    duration: 15,
                    estimatedCalories: 50,
                    intensity: "Recovery",
                    symbolName: "figure.flexibility",
                    tint: .blue
                )
            ]
        }

        if remainingCalories > 300 {
            return [
                WorkoutRecommendation(
                    title: "Interval Run",
                    subtitle: "Alternate fast pushes with easy recovery jogs.",
                    duration: 30,
                    estimatedCalories: 320,
                    intensity: "Hard",
                    symbolName: "figure.run",
                    tint: .orange
                ),
                WorkoutRecommendation(
                    title: "Full Body Strength",
                    subtitle: "Squats, push-ups, rows, lunges, and core work.",
                    duration: 35,
                    estimatedCalories: 260,
                    intensity: "Medium",
                    symbolName: "dumbbell.fill",
                    tint: .purple
                ),
                WorkoutRecommendation(
                    title: "Cycling Session",
                    subtitle: "Steady pace ride to close a bigger calorie gap.",
                    duration: 40,
                    estimatedCalories: 360,
                    intensity: "Medium",
                    symbolName: "bicycle",
                    tint: .teal
                )
            ]
        }

        if remainingCalories > 120 {
            return [
                WorkoutRecommendation(
                    title: "Brisk Walk",
                    subtitle: "A focused walk that fits between daily tasks.",
                    duration: 30,
                    estimatedCalories: 160,
                    intensity: "Easy",
                    symbolName: "figure.walk",
                    tint: .green
                ),
                WorkoutRecommendation(
                    title: "Bodyweight Circuit",
                    subtitle: "Three rounds of squats, planks, and mountain climbers.",
                    duration: 20,
                    estimatedCalories: 180,
                    intensity: "Medium",
                    symbolName: "figure.strengthtraining.traditional",
                    tint: .indigo
                )
            ]
        }

        return [
            WorkoutRecommendation(
                title: "Quick Finisher",
                subtitle: "Short movement burst to finish today's goal.",
                duration: 10,
                estimatedCalories: max(Int(remainingCalories.rounded()), 40),
                intensity: "Light",
                symbolName: "bolt.heart.fill",
                tint: .orange
            ),
            WorkoutRecommendation(
                title: "Evening Stretch",
                subtitle: "Relax the body while keeping the habit alive.",
                duration: 12,
                estimatedCalories: 35,
                intensity: "Recovery",
                symbolName: "figure.mind.and.body",
                tint: .blue
            )
        ]
    }
}

private struct CalorieProgressCard: View {
    let activeCalories: Double
    let cameraCalories: Double
    let dailyCalorieGoal: Double
    let remainingCalories: Double
    let progress: Double
    let progressPercentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Calories")
                        .font(.headline)

                    Text("\(activeCalories, format: .number.precision(.fractionLength(0))) kcal")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }

                Spacer()

                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(.orange.opacity(0.14), in: Circle())
            }

            ProgressView(value: progress)
                .tint(.orange)
                .scaleEffect(x: 1, y: 1.8, anchor: .center)
                .accessibilityLabel("Daily calorie progress")
                .accessibilityValue("\(Int(progress * 100)) percent")

            HStack {
                SummaryMetric(
                    title: "Daily Goal",
                    value: "\(dailyCalorieGoal.formatted(.number.precision(.fractionLength(0)))) kcal"
                )

                Spacer()

                SummaryMetric(title: "Progress", value: "\(progressPercentage)%")

                Spacer()

                SummaryMetric(
                    title: "Remaining",
                    value: "\(remainingCalories.formatted(.number.precision(.fractionLength(0)))) kcal"
                )
            }

            if cameraCalories > 0 {
                Label(
                    "\(Int(cameraCalories)) kcal added from tracked workouts",
                    systemImage: "camera.viewfinder"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct GoalEditorCard: View {
    @Binding var dailyCalorieGoal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Goal")
                    .font(.headline)

                Spacer()

                Text("\(dailyCalorieGoal, format: .number.precision(.fractionLength(0))) kcal")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Slider(value: $dailyCalorieGoal, in: 100...1500, step: 25) {
                Text("Daily calorie goal")
            } minimumValueLabel: {
                Text("100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("1500")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(.orange)

            Stepper("Adjust by 25 kcal", value: $dailyCalorieGoal, in: 100...1500, step: 25)
                .font(.subheadline)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StepCountCard: View {
    let stepCount: Double

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "shoeprints.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(.green.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("Steps Today")
                    .font(.headline)

                Text(stepCount.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("From Apple Health")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Steps today")
        .accessibilityValue(stepCount.formatted(.number.precision(.fractionLength(0))))
    }
}

private struct RecommendationEntryCard: View {
    let recommendationCount: Int
    let progressPercentage: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(.yellow.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Recommendations")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(recommendationCount) plans based on \(progressPercentage)% progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens workout recommendations")
    }
}

private struct WorkoutRecommendationsSection: View {
    let recommendations: [WorkoutRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout Recommendations")
                        .font(.headline)

                    Text("Based on today's calorie progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 12) {
                ForEach(recommendations) { recommendation in
                    WorkoutRecommendationRow(recommendation: recommendation)
                }
            }
        }
    }
}

private struct WorkoutRecommendationsDetailView: View {
    let recommendations: [WorkoutRecommendation]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Workout Recommendations")
                    .font(.largeTitle.bold())

                Text("Plans adjust from your daily calorie progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                WorkoutRecommendationsSection(recommendations: recommendations)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Recommendations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WorkoutRecommendationRow: View {
    let recommendation: WorkoutRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: recommendation.symbolName)
                .font(.title3)
                .foregroundStyle(recommendation.tint)
                .frame(width: 42, height: 42)
                .background(recommendation.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recommendation.title)
                        .font(.headline)

                    Spacer()

                    Text(recommendation.intensity)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(recommendation.tint)
                        .background(recommendation.tint.opacity(0.12), in: Capsule())
                }

                Text(recommendation.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    Label("\(recommendation.duration) min", systemImage: "clock")
                    Label("\(recommendation.estimatedCalories) kcal", systemImage: "flame")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
    }
}

struct FitnessDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        FitnessDashboardView()
    }
}
