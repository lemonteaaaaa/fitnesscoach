//
//  MovementTrackerView.swift
//  fitnesscoach
//

import AVFoundation
import Combine
import SwiftUI
import UIKit
import Vision

struct MovementTrackerView: View {
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal = 500.0
    @AppStorage("trackedWorkoutCalories") private var trackedWorkoutCalories = 0.0
    @AppStorage("trackedWorkoutDate") private var trackedWorkoutDate = ""
    @StateObject private var healthKitManager = HealthKitManager()

    private var cameraCaloriesToday: Double {
        DailyTrackingDate.caloriesForToday(
            trackedWorkoutCalories,
            storedDate: trackedWorkoutDate
        )
    }

    private var totalActiveCalories: Double {
        healthKitManager.activeCalories + cameraCaloriesToday
    }

    private var remainingCalories: Double {
        max(dailyCalorieGoal - totalActiveCalories, 0)
    }

    private var progress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(totalActiveCalories / dailyCalorieGoal, 1)
    }

    private var recommendations: [TrackableWorkoutRecommendation] {
        TrackableWorkoutRecommendation.recommendations(remainingCalories: remainingCalories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TrackerGoalSummaryCard(
                        activeCalories: totalActiveCalories,
                        cameraCalories: cameraCaloriesToday,
                        dailyCalorieGoal: dailyCalorieGoal,
                        remainingCalories: remainingCalories,
                        progress: progress
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommended Camera Workouts")
                            .font(.headline)

                        ForEach(recommendations) { recommendation in
                            NavigationLink {
                                MovementCameraSessionView(recommendation: recommendation)
                            } label: {
                                TrackableWorkoutCard(recommendation: recommendation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await healthKitManager.requestAuthorization()
                await healthKitManager.loadTodayHealthSummary()
            }
            .refreshable {
                await healthKitManager.loadTodayHealthSummary()
            }
        }
    }
}

private struct MovementCameraSessionView: View {
    let recommendation: TrackableWorkoutRecommendation

    @AppStorage("totalSquatReps") private var totalSquatReps = 0
    @AppStorage("totalPushupReps") private var totalPushupReps = 0
    @AppStorage("trackedWorkoutCalories") private var trackedWorkoutCalories = 0.0
    @AppStorage("trackedWorkoutDate") private var trackedWorkoutDate = ""
    @StateObject private var poseAnalyzer: PoseAnalyzer
    @StateObject private var cameraModel = CameraPoseTrackingModel()
    @State private var lastSavedRepCount = 0
    @State private var sessionCalories = 0.0

    private var caloriesPerRep: Double {
        guard recommendation.targetReps > 0 else { return 0 }
        return Double(recommendation.estimatedCalories) / Double(recommendation.targetReps)
    }

    init(recommendation: TrackableWorkoutRecommendation) {
        self.recommendation = recommendation
        _poseAnalyzer = StateObject(
            wrappedValue: PoseAnalyzer(selectedCategory: recommendation.exerciseCategory)
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: cameraModel.session)
                .ignoresSafeArea(edges: .top)
                .overlay {
                    if let points = poseAnalyzer.lastPoints {
                        SkeletonOverlayView(joints: points)
                    }
                }
                .overlay {
                    if cameraModel.authorizationStatus == .denied {
                        CameraUnavailableView(
                            title: "Camera access needed",
                            message: "Enable camera permission in Settings to track your movement."
                        )
                    } else if let errorMessage = cameraModel.errorMessage {
                        CameraUnavailableView(
                            title: "Camera unavailable",
                            message: errorMessage
                        )
                    }
                }

            VStack(spacing: 16) {
                TrackerStatsPanel(
                    poseAnalyzer: poseAnalyzer,
                    targetReps: recommendation.targetReps,
                    caloriesEarned: sessionCalories,
                    caloriesPerRep: caloriesPerRep
                )

                Button {
                    poseAnalyzer.reset()
                    lastSavedRepCount = 0
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle(recommendation.exerciseCategory.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            resetTrackedCaloriesIfNeeded()
            await cameraModel.configure(with: poseAnalyzer)
        }
        .onDisappear {
            cameraModel.stop()
        }
        .onChange(of: poseAnalyzer.repCount) { _, newValue in
            saveReps(from: newValue)
        }
    }

    private func saveReps(from newValue: Int) {
        guard newValue > lastSavedRepCount else {
            lastSavedRepCount = newValue
            return
        }

        let addedReps = newValue - lastSavedRepCount
        let addedCalories = Double(addedReps) * caloriesPerRep
        resetTrackedCaloriesIfNeeded()
        trackedWorkoutCalories += addedCalories
        sessionCalories += addedCalories

        switch poseAnalyzer.selectedCategory {
        case .squat:
            totalSquatReps += addedReps
        case .pushup:
            totalPushupReps += addedReps
        case .plank, .jumpingJack, .lunge, .burpee, .situp, .mountainClimber, .shoulderPress, .bicepCurl:
            break
        }

        lastSavedRepCount = newValue
    }

    private func resetTrackedCaloriesIfNeeded() {
        let todayKey = DailyTrackingDate.todayKey
        guard trackedWorkoutDate != todayKey else { return }
        trackedWorkoutDate = todayKey
        trackedWorkoutCalories = 0
    }
}

private struct TrackableWorkoutRecommendation: Identifiable {
    let id = UUID()
    let exerciseCategory: ExerciseCategory
    let title: String
    let subtitle: String
    let targetReps: Int
    let estimatedCalories: Int
    let intensity: String
    let symbolName: String
    let tint: Color

    static func recommendations(remainingCalories: Double) -> [TrackableWorkoutRecommendation] {
        if remainingCalories > 300 {
            return [
                TrackableWorkoutRecommendation(
                    exerciseCategory: .squat,
                    title: "Squat Strength",
                    subtitle: "Lower-body reps to close a bigger calorie gap.",
                    targetReps: 24,
                    estimatedCalories: 120,
                    intensity: "Medium",
                    symbolName: "figure.strengthtraining.traditional",
                    tint: .orange
                ),
                TrackableWorkoutRecommendation(
                    exerciseCategory: .pushup,
                    title: "Push Up Set",
                    subtitle: "Upper-body work with camera rep tracking.",
                    targetReps: 18,
                    estimatedCalories: 90,
                    intensity: "Medium",
                    symbolName: "figure.core.training",
                    tint: .blue
                )
            ]
        }

        if remainingCalories > 120 {
            return [
                TrackableWorkoutRecommendation(
                    exerciseCategory: .squat,
                    title: "Squat Circuit",
                    subtitle: "A compact set matched to today's remaining goal.",
                    targetReps: 18,
                    estimatedCalories: 80,
                    intensity: "Light",
                    symbolName: "figure.strengthtraining.traditional",
                    tint: .green
                ),
                TrackableWorkoutRecommendation(
                    exerciseCategory: .pushup,
                    title: "Push Up Finisher",
                    subtitle: "Short tracked set for extra movement.",
                    targetReps: 12,
                    estimatedCalories: 60,
                    intensity: "Light",
                    symbolName: "figure.core.training",
                    tint: .teal
                )
            ]
        }

        return [
            TrackableWorkoutRecommendation(
                exerciseCategory: .squat,
                title: "Quick Squat Check",
                subtitle: "A short tracked session to keep the habit alive.",
                targetReps: 10,
                estimatedCalories: 40,
                intensity: "Easy",
                symbolName: "figure.strengthtraining.traditional",
                tint: .purple
            )
        ]
    }
}

private struct TrackerGoalSummaryCard: View {
    let activeCalories: Double
    let cameraCalories: Double
    let dailyCalorieGoal: Double
    let remainingCalories: Double
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calorie Goal")
                        .font(.headline)

                    Text("\(Int(activeCalories)) / \(Int(dailyCalorieGoal)) kcal")
                        .font(.title2.bold())
                }

                Spacer()

                Text("\(Int(remainingCalories)) left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            ProgressView(value: progress)
                .tint(.orange)

            if cameraCalories > 0 {
                Label(
                    "\(Int(cameraCalories)) kcal from camera workouts",
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

private struct TrackableWorkoutCard: View {
    let recommendation: TrackableWorkoutRecommendation

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: recommendation.symbolName)
                .font(.title3)
                .foregroundStyle(recommendation.tint)
                .frame(width: 44, height: 44)
                .background(recommendation.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recommendation.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(recommendation.intensity)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(recommendation.tint)
                }

                Text(recommendation.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label("\(recommendation.targetReps) reps", systemImage: "target")
                    Label("\(recommendation.estimatedCalories) kcal", systemImage: "flame")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: "camera.viewfinder")
                .font(.headline)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens camera tracking")
    }
}

private struct TrackerStatsPanel: View {
    @ObservedObject var poseAnalyzer: PoseAnalyzer
    let targetReps: Int
    let caloriesEarned: Double
    let caloriesPerRep: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poseAnalyzer.selectedCategory.rawValue)
                        .font(.headline)

                    Text(poseAnalyzer.feedbackText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(poseAnalyzer.repCount)/\(targetReps)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())

                    Text("reps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label("\(Int(caloriesEarned.rounded())) kcal earned", systemImage: "flame.fill")
                    .foregroundStyle(.orange)

                Spacer()

                Text("+\(caloriesPerRep, format: .number.precision(.fractionLength(1))) kcal / rep")
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(poseAnalyzer.selectedCategory.rawValue), \(poseAnalyzer.repCount) of \(targetReps) repetitions, \(Int(caloriesEarned.rounded())) calories earned")
    }
}

private struct CameraUnavailableView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private final class CameraPoseTrackingModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    let session = AVCaptureSession()

    private let frameQueue = DispatchQueue(label: "fitnesscoach.pose.frames")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var frameHandler: PoseFrameHandler?

    func configure(with poseAnalyzer: PoseAnalyzer) async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            startSession(with: poseAnalyzer)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            if granted {
                startSession(with: poseAnalyzer)
            }
        default:
            authorizationStatus = .denied
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func startSession(with poseAnalyzer: PoseAnalyzer) {
        if frameHandler == nil {
            frameHandler = PoseFrameHandler(poseAnalyzer: poseAnalyzer)
        }

        configureSessionIfNeeded()

        if !session.isRunning {
            session.startRunning()
        }
    }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            publishError("Front camera is not available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                publishError("Unable to add camera input.")
                return
            }

            session.addInput(input)
        } catch {
            publishError(error.localizedDescription)
            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(frameHandler, queue: frameQueue)

        guard session.canAddOutput(videoOutput) else {
            publishError("Unable to add camera output.")
            return
        }

        session.addOutput(videoOutput)
    }

    private func publishError(_ message: String) {
        errorMessage = message
    }
}

private final class PoseFrameHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let poseAnalyzer: PoseAnalyzer
    nonisolated(unsafe) private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

    init(poseAnalyzer: PoseAnalyzer) {
        self.poseAnalyzer = poseAnalyzer
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let requestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored
        )

        do {
            try requestHandler.perform([bodyPoseRequest])
            guard let observation = bodyPoseRequest.results?.first else { return }
            guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
            let posePoints = BodyJoint.posePoints(from: recognizedPoints)

            Task { @MainActor in
                poseAnalyzer.analyze(points: posePoints)
            }
        } catch {
            return
        }
    }
}

private struct SkeletonOverlayView: View {
    let joints: [BodyJoint: PosePoint]

    private let connections: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            Path { path in
                for (jointA, jointB) in connections {
                    if let pointA = point(for: jointA, in: size), let pointB = point(for: jointB, in: size) {
                        path.move(to: pointA)
                        path.addLine(to: pointB)
                    }
                }
            }
            .stroke(Color.green.opacity(0.7), lineWidth: 3)

            ForEach(Array(joints.keys), id: \.self) { jointName in
                if let pt = point(for: jointName, in: size) {
                    Circle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 10, height: 10)
                        .position(pt)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func point(for joint: BodyJoint, in size: CGSize) -> CGPoint? {
        guard let recognizedPoint = joints[joint], recognizedPoint.confidence > 0.1 else { return nil }
        return CGPoint(
            x: recognizedPoint.x * size.width,
            y: (1 - recognizedPoint.y) * size.height
        )
    }
}

struct MovementTrackerView_Previews: PreviewProvider {
    static var previews: some View {
    MovementTrackerView()
    }
}
