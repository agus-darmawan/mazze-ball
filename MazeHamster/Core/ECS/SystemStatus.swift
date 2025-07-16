//
//  SystemStatus.swift
//  MazeHamster
//
//  Created by Darmawan on 16/07/25.
//


import Foundation

// MARK: - System Status

/// Represents the current status of the game coordinator system
enum SystemStatus {
    case idle
    case initializing
    case ready
    case running
    case paused
    case stopping
    case completed
    case failed
    case error(String)
}

// MARK: - System Status Info

/// Comprehensive information about the current system status
struct SystemStatusInfo {
    let coordinatorStatus: SystemStatus
    let isInitialized: Bool
    let isRunning: Bool
    let ecsSystemsCount: Int
    let activeEntitiesCount: Int
    let gameState: GameState
    
    init(coordinatorStatus: SystemStatus, isInitialized: Bool, isRunning: Bool, ecsSystemsCount: Int, activeEntitiesCount: Int, gameState: GameState) {
        self.coordinatorStatus = coordinatorStatus
        self.isInitialized = isInitialized
        self.isRunning = isRunning
        self.ecsSystemsCount = ecsSystemsCount
        self.activeEntitiesCount = activeEntitiesCount
        self.gameState = gameState
    }
}

// MARK: - System Status Extensions

extension SystemStatus {
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .initializing: return "Initializing"
        case .ready: return "Ready"
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .running, .paused:
            return true
        default:
            return false
        }
    }
    
    var canTransitionTo: [SystemStatus] {
        switch self {
        case .idle:
            return [.initializing]
        case .initializing:
            return [.ready, .failed, .error("")]
        case .ready:
            return [.running, .initializing]
        case .running:
            return [.paused, .stopping, .completed, .failed]
        case .paused:
            return [.running, .stopping]
        case .stopping:
            return [.idle]
        case .completed, .failed:
            return [.idle, .initializing]
        case .error:
            return [.idle, .initializing]
        }
    }
}

extension SystemStatusInfo {
    var debugDescription: String {
        return """
        === System Status Info ===
        Coordinator Status: \(coordinatorStatus.description)
        Initialized: \(isInitialized)
        Running: \(isRunning)
        ECS Systems: \(ecsSystemsCount)
        Active Entities: \(activeEntitiesCount)
        Game State: \(gameState)
        """
    }
}