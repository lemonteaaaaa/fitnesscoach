//
//  PoseAnalyzer.swift
//  fitnesscoach
//

import Foundation
import Combine
import Vision
import CoreGraphics

struct PosePoint: Sendable {
    let x: CGFloat
    let y: CGFloat
    let confidence: Float

    var location: CGPoint {
        CGPoint(x: x, y: y)
    }

    nonisolated init(recognizedPoint: VNRecognizedPoint) {
        x = recognizedPoint.location.x
        y = recognizedPoint.location.y
        confidence = recognizedPoint.confidence
    }
}

enum BodyJoint: String, CaseIterable, Sendable {
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    nonisolated var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .leftShoulder:
            .leftShoulder
        case .rightShoulder:
            .rightShoulder
        case .leftElbow:
            .leftElbow
        case .rightElbow:
            .rightElbow
        case .leftWrist:
            .leftWrist
        case .rightWrist:
            .rightWrist
        case .leftHip:
            .leftHip
        case .rightHip:
            .rightHip
        case .leftKnee:
            .leftKnee
        case .rightKnee:
            .rightKnee
        case .leftAnkle:
            .leftAnkle
        case .rightAnkle:
            .rightAnkle
        }
    }
}

enum ExerciseCategory: String, CaseIterable, Identifiable {
    case squat = "Squat"
    case pushup = "Push Up"
    case plank = "Plank"
    case jumpingJack = "Jumping Jack"
    case lunge = "Lunge"
    case burpee = "Burpee"
    case situp = "Sit Up"
    case mountainClimber = "Mountain Climber"
    case shoulderPress = "Shoulder Press"
    case bicepCurl = "Bicep Curl"
    
    var id: String { self.rawValue }
}

@MainActor
class PoseAnalyzer: ObservableObject {
    @Published var repCount: Int = 0
    @Published var selectedCategory: ExerciseCategory = .squat
    @Published var feedbackText: String = "Ready"
    @Published var lastPoints: [BodyJoint: PosePoint]?
    
    private var isSquatting: Bool = false
    private var isDownForPushup: Bool = false
    private var squatDownFrames = 0
    private var squatUpFrames = 0
    private var pushupDownFrames = 0
    private var pushupUpFrames = 0

    init(selectedCategory: ExerciseCategory = .squat) {
        self.selectedCategory = selectedCategory
    }
    
    func reset() {
        repCount = 0
        isSquatting = false
        isDownForPushup = false
        squatDownFrames = 0
        squatUpFrames = 0
        pushupDownFrames = 0
        pushupUpFrames = 0
        feedbackText = "Ready"
        lastPoints = nil
    }
    
    func analyze(observation: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        analyze(points: BodyJoint.posePoints(from: recognizedPoints))
    }

    func analyze(points recognizedPoints: [BodyJoint: PosePoint]) {
        lastPoints = recognizedPoints
        
        switch selectedCategory {
        case .squat:
            analyzeSquat(points: recognizedPoints)
        case .pushup:
            analyzePushup(points: recognizedPoints)
        case .plank:
            feedbackText = "Belum didukung"
        case .jumpingJack:
            feedbackText = "Belum didukung"
        case .lunge:
            feedbackText = "Belum didukung"
        case .burpee:
            feedbackText = "Belum didukung"
        case .situp:
            feedbackText = "Belum didukung"
        case .mountainClimber:
            feedbackText = "Belum didukung"
        case .shoulderPress:
            feedbackText = "Belum didukung"
        case .bicepCurl:
            feedbackText = "Belum didukung"
        }
    }
    
    private func analyzeSquat(points: [BodyJoint: PosePoint]) {
        guard let angle = bestAngle(
            points: points,
            left: (.leftHip, .leftKnee, .leftAnkle),
            right: (.rightHip, .rightKnee, .rightAnkle)
        ) else {
            feedbackText = "Move full body into frame"
            return
        }

        if angle < 115 {
            squatDownFrames += 1
            squatUpFrames = 0

            if squatDownFrames >= 3, !isSquatting {
                isSquatting = true
                feedbackText = "Good depth. Stand up."
            }
        } else if angle > 155 {
            squatUpFrames += 1
            squatDownFrames = 0

            if squatUpFrames >= 3, isSquatting {
                isSquatting = false
                repCount += 1
                feedbackText = "Great! Rep \(repCount)"
            }
        } else {
            squatDownFrames = 0
            squatUpFrames = 0
            feedbackText = isSquatting ? "Stand all the way up" : "Lower into squat"
        }
    }
    
    private func analyzePushup(points: [BodyJoint: PosePoint]) {
        guard let angle = bestAngle(
            points: points,
            left: (.leftShoulder, .leftElbow, .leftWrist),
            right: (.rightShoulder, .rightElbow, .rightWrist)
        ) else {
            feedbackText = "Keep shoulders, elbows, and wrists visible"
            return
        }

        if angle < 100 {
            pushupDownFrames += 1
            pushupUpFrames = 0

            if pushupDownFrames >= 3, !isDownForPushup {
                isDownForPushup = true
                feedbackText = "Good depth. Push up."
            }
        } else if angle > 155 {
            pushupUpFrames += 1
            pushupDownFrames = 0

            if pushupUpFrames >= 3, isDownForPushup {
                isDownForPushup = false
                repCount += 1
                feedbackText = "Great! Rep \(repCount)"
            }
        } else {
            pushupDownFrames = 0
            pushupUpFrames = 0
            feedbackText = isDownForPushup ? "Extend your arms" : "Lower your chest"
        }
    }

    private func bestAngle(
        points: [BodyJoint: PosePoint],
        left: (BodyJoint, BodyJoint, BodyJoint),
        right: (BodyJoint, BodyJoint, BodyJoint)
    ) -> CGFloat? {
        let angles = [
            angleIfVisible(points: points, joints: left),
            angleIfVisible(points: points, joints: right)
        ].compactMap { $0 }

        return angles.min()
    }

    private func angleIfVisible(
        points: [BodyJoint: PosePoint],
        joints: (BodyJoint, BodyJoint, BodyJoint)
    ) -> CGFloat? {
        guard let first = points[joints.0], first.confidence > 0.35,
              let middle = points[joints.1], middle.confidence > 0.35,
              let last = points[joints.2], last.confidence > 0.35 else {
            return nil
        }

        return angleBetweenPoints(
            a: first.location,
            b: middle.location,
            c: last.location
        )
    }
    
    // Calculates the angle ABC in degrees (B is the vertex)
    private func angleBetweenPoints(a: CGPoint, b: CGPoint, c: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let cb = CGPoint(x: b.x - c.x, y: b.y - c.y)

        let dotProduct = ab.x * cb.x + ab.y * cb.y
        let magnitudeAB = hypot(ab.x, ab.y)
        let magnitudeCB = hypot(cb.x, cb.y)
        guard magnitudeAB > 0, magnitudeCB > 0 else { return 0 }

        let cosine = min(max(dotProduct / (magnitudeAB * magnitudeCB), -1), 1)
        return acos(cosine) * 180 / .pi
    }
}

extension BodyJoint {
    nonisolated static func posePoints(
        from recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> [BodyJoint: PosePoint] {
        Dictionary(uniqueKeysWithValues: allCases.compactMap { joint in
            guard let point = recognizedPoints[joint.visionName] else { return nil }
            return (joint, PosePoint(recognizedPoint: point))
        })
    }
}
