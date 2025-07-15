import Foundation
import RealityKit
import simd

// MARK: - Game State Models

/// Represents the current state of the game
enum GameState {
    case menu
    case playing
    case paused
    case completed
    case failed
}

/// Represents tilt data from device motion
struct TiltData {
    let roll: Float
    let pitch: Float
    let timestamp: TimeInterval
    
    /// Create tilt data with clamped values to prevent extreme rotations
    init(roll: Float, pitch: Float, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        let maxTilt: Float = .pi / 4  // 45 degrees
        self.roll = max(-maxTilt, min(maxTilt, roll))
        self.pitch = max(-maxTilt, min(maxTilt, pitch))
        self.timestamp = timestamp
    }
    
    /// Convert tilt data to quaternion rotation
    var quaternion: simd_quatf {
        let rotationX = simd_quatf(angle: -pitch, axis: [1, 0, 0])
        let rotationZ = simd_quatf(angle: -roll, axis: [0, 0, 1])
        return rotationZ * rotationX
    }
}

/// Represents the configuration for the maze
struct MazeConfiguration {
    let width: Int
    let height: Int
    let cellSize: Float
    let wallHeight: Float
    let wallThickness: Float
    
    static let `default` = MazeConfiguration(
        width: 10,
        height: 10,
        cellSize: 1.0,
        wallHeight: 1.0,
        wallThickness: 0.1
    )
}

/// Enhanced maze data structure that includes generation metadata
struct MazeData {
    let configuration: MazeConfiguration
    let cells: [[MazeCell]]
    let startPosition: SIMD2<Int>
    let exitPosition: SIMD2<Int>
    let generationSeed: UInt32
    
    init(configuration: MazeConfiguration, cells: [[MazeCell]], seed: UInt32 = 0) {
        self.configuration = configuration
        self.cells = cells
        self.startPosition = SIMD2<Int>(0, 0)
        self.exitPosition = SIMD2<Int>(configuration.width - 1, configuration.height - 1)
        self.generationSeed = seed
    }
    
    /// Get world position for a maze cell
    func worldPosition(for cell: SIMD2<Int>) -> SIMD3<Float> {
        return SIMD3<Float>(
            Float(cell.x) * configuration.cellSize,
            0,
            Float(cell.y) * configuration.cellSize
        )
    }
    
    /// Get the center position of the maze
    var centerPosition: SIMD3<Float> {
        return SIMD3<Float>(
            Float(configuration.width - 1) * configuration.cellSize * 0.5,
            0,
            Float(configuration.height - 1) * configuration.cellSize * 0.5
        )
    }
}

/// Represents physics material configurations
struct PhysicsMaterials {
    let ball: PhysicsMaterialResource
    let wall: PhysicsMaterialResource
    let floor: PhysicsMaterialResource
    
    static let `default` = PhysicsMaterials(
        ball: PhysicsMaterialResource.generate(
            staticFriction: 0.9,
            dynamicFriction: 0.7,
            restitution: 0.1
        ),
        wall: PhysicsMaterialResource.generate(
            staticFriction: 0.8,
            dynamicFriction: 0.6,
            restitution: 0.2
        ),
        floor: PhysicsMaterialResource.generate(
            staticFriction: 0.7,
            dynamicFriction: 0.5,
            restitution: 0.1
        )
    )
}

/// Represents visual material configurations
struct VisualMaterials {
    let ball: SimpleMaterial
    let wall: SimpleMaterial
    let floor: SimpleMaterial
    let exit: SimpleMaterial
    
    static let `default` = VisualMaterials(
        ball: SimpleMaterial(color: .red, isMetallic: true),
        wall: SimpleMaterial(color: .blue, isMetallic: false),
        floor: SimpleMaterial(color: .gray, isMetallic: false),
        exit: SimpleMaterial(color: .green, isMetallic: false)
    )
}

/// Represents game configuration
struct GameConfiguration {
    let maze: MazeConfiguration
    let physicsMaterials: PhysicsMaterials
    let visualMaterials: VisualMaterials
    let ballRadius: Float
    let exitRadius: Float
    let cameraHeight: Float
    let catSleepDuration: TimeInterval
    
    static let `default` = GameConfiguration(
        maze: .default,
        physicsMaterials: .default,
        visualMaterials: .default,
        ballRadius: 0.2,
        exitRadius: 0.3,
        cameraHeight: 8.0,
        catSleepDuration: 3.0
    )
} 