//
//  PathfindingServiceProtocol.swift
//  MazeHamster
//
//  Created by Darmawan on 16/07/25.
//


import Foundation
import RealityKit
import simd

// MARK: - Pathfinding Service Protocol

/// Protocol defining the interface for pathfinding services
protocol PathfindingServiceProtocol: ObservableObject {
    /// Set the maze service for pathfinding calculations
    func setMazeService(_ service: MazeService)
    
    /// Find path from start to target position using pathfinding algorithm
    func findPath(from startWorld: SIMD3<Float>, to targetWorld: SIMD3<Float>) -> [SIMD3<Float>]
    
    /// Check if there's a direct line of sight between two positions
    func hasLineOfSight(from startWorld: SIMD3<Float>, to targetWorld: SIMD3<Float>) -> Bool
    
    /// Get next waypoint from current position towards target
    func getNextWaypoint(from currentWorld: SIMD3<Float>, to targetWorld: SIMD3<Float>) -> SIMD3<Float>?
    
    /// Smooth the path by removing unnecessary waypoints
    func smoothPath(_ path: [SIMD3<Float>]) -> [SIMD3<Float>]
    
    /// Clear the path cache (call when maze changes)
    func clearPathCache()
}

// MARK: - Pathfinding Node

/// Structure representing a node in the pathfinding grid
struct PathfindingNode {
    let position: SIMD2<Int>
    var gScore: Float = Float.infinity
    var fScore: Float = Float.infinity
    var cameFrom: SIMD2<Int>?
    var isWalkable: Bool = true
    
    init(position: SIMD2<Int>, isWalkable: Bool = true) {
        self.position = position
        self.isWalkable = isWalkable
    }
}

// MARK: - Pathfinding Result

/// Structure representing the result of a pathfinding operation
struct PathfindingResult {
    let path: [SIMD3<Float>]
    let success: Bool
    let pathLength: Float
    let computationTime: TimeInterval
    
    init(path: [SIMD3<Float>] = [], success: Bool = false, pathLength: Float = 0, computationTime: TimeInterval = 0) {
        self.path = path
        self.success = success
        self.pathLength = pathLength
        self.computationTime = computationTime
    }
}

// MARK: - Navigation Mesh Protocol

/// Protocol for navigation mesh generation and queries
protocol NavigationMeshProtocol {
    /// Generate navigation mesh from maze data
    func generateNavMesh(from maze: MazeData) -> NavigationMesh
    
    /// Find nearest walkable position on the navigation mesh
    func findNearestWalkablePosition(_ position: SIMD3<Float>) -> SIMD3<Float>?
    
    /// Check if position is on the navigation mesh
    func isPositionWalkable(_ position: SIMD3<Float>) -> Bool
}

// MARK: - Navigation Mesh

/// Simple navigation mesh representation
struct NavigationMesh {
    let walkableAreas: [WalkableArea]
    let connections: [NavMeshConnection]
    
    struct WalkableArea {
        let bounds: SIMD4<Float> // x, z, width, height
        let centerY: Float
    }
    
    struct NavMeshConnection {
        let fromArea: Int
        let toArea: Int
        let connectionPoint: SIMD3<Float>
    }
}

// MARK: - Pathfinding Algorithm Types

/// Enumeration of supported pathfinding algorithms
enum PathfindingAlgorithm {
    case aStar
    case dijkstra
    case jumpPointSearch
    case hierarchicalAStar
}

// MARK: - Pathfinding Configuration

/// Configuration for pathfinding behavior
struct PathfindingConfiguration {
    let algorithm: PathfindingAlgorithm
    let allowDiagonalMovement: Bool
    let smoothingEnabled: Bool
    let cacheEnabled: Bool
    let maxSearchNodes: Int
    let heuristicWeight: Float
    
    static let `default` = PathfindingConfiguration(
        algorithm: .aStar,
        allowDiagonalMovement: false, // For maze navigation, typically false
        smoothingEnabled: true,
        cacheEnabled: true,
        maxSearchNodes: 1000,
        heuristicWeight: 1.0
    )
}

// MARK: - Pathfinding Debug Info

/// Debug information for pathfinding operations
struct PathfindingDebugInfo {
    let searchedNodes: Int
    let pathLength: Int
    let computationTime: TimeInterval
    let algorithm: PathfindingAlgorithm
    let cacheHit: Bool
    
    var description: String {
        return """
        Pathfinding Debug:
        - Algorithm: \(algorithm)
        - Searched Nodes: \(searchedNodes)
        - Path Length: \(pathLength)
        - Computation Time: \(String(format: "%.3f", computationTime))ms
        - Cache Hit: \(cacheHit)
        """
    }
}
