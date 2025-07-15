import Foundation
import RealityKit
import SwiftUI
import Combine

/// Game coordinator that manages the overall game flow and system interactions
class GameCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isInitialized: Bool = false
    @Published var systemStatus: SystemStatus = .idle
    
    // MARK: - Services
    
    private let inputService: InputService
    private let physicsService: PhysicsService
    private let mazeService: MazeService
    private let gameService: GameService
    private let cameraService: CameraService
    private let entityFactory: EntityFactory
    
    // MARK: - ECS
    
    private let ecsWorld: ECSWorld
    
    // MARK: - Game State
    
    private var gameConfiguration: GameConfiguration
    private var currentScene: Entity?
    private var isRunning: Bool = false
    private var catEntity: Entity?
    private var catEntityId: UUID?
    private var ballEntityId: UUID?
    
    // MARK: - Combine
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(configuration: GameConfiguration = .default) {
        self.gameConfiguration = configuration
        
        // Initialize services
        self.inputService = InputService()
        self.physicsService = PhysicsService()
        self.mazeService = MazeService()
        self.gameService = GameService()
        self.cameraService = CameraService()
        self.entityFactory = EntityFactory()
        
        // Initialize ECS
        self.ecsWorld = ECSWorld()
        
        setupCoordinator()
    }
    
    // MARK: - Setup
    
    private func setupCoordinator() {
        // Setup service dependencies
        gameService.setMazeService(mazeService)
        
        // Setup bindings
        setupBindings()
        
        // Initialize ECS
        ecsWorld.initialize()
        
        systemStatus = .ready
        isInitialized = true
        
        print("🎮 GameCoordinator initialized successfully")
    }
    
    private func setupBindings() {
        // Monitor game state changes
        gameService.$gameState
            .sink { [weak self] gameState in
                self?.handleGameStateChange(gameState)
            }
            .store(in: &cancellables)
        
        // Monitor input changes
        inputService.tiltData
            .sink { [weak self] tiltData in
                self?.handleInputChange(tiltData)
            }
            .store(in: &cancellables)
        
        // Monitor maze changes
        mazeService.$maze
            .sink { [weak self] (maze: MazeData) in
                self?.handleMazeChange()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Start the game coordinator
    func startCoordinator() {
        guard isInitialized else {
            print("⚠️ Cannot start coordinator: Not initialized")
            return
        }
        
        systemStatus = .running
        isRunning = true
        
        // Start services
        inputService.startMonitoring()
        
        print("🚀 GameCoordinator started")
    }
    
    /// Stop the game coordinator
    func stopCoordinator() {
        systemStatus = .stopping
        isRunning = false
        
        // Stop services
        inputService.stopMonitoring()
        gameService.resetGame()
        
        // Shutdown ECS
        ecsWorld.shutdown()
        
        systemStatus = .idle
        print("🛑 GameCoordinator stopped")
    }
    
    /// Create a new game scene
    func createGameScene() -> Entity {
        systemStatus = .initializing
        
        // Create main scene
        let scene = entityFactory.createContainer(name: "GameScene")
        currentScene = scene
        
        // Create maze world
        let mazeWorld = entityFactory.createContainer(name: "MazeWorld")
        
        // Generate maze entities
        let mazeEntities = mazeService.createMazeEntities()
        
        // Setup maze physics
        setupMazePhysics(entities: mazeEntities)
        
        // Add maze entities to world
        for entity in mazeEntities {
            mazeWorld.addChild(entity)
        }
        
        // Create and setup ball
        let ball = entityFactory.createMazeBall()
        ball.position = mazeService.getStartPosition()
        physicsService.setupBallPhysics(for: ball, withMaterial: gameConfiguration.physicsMaterials.ball)
        
        // Create ball entity for ECS tracking
        ballEntityId = UUID()
        let ballTransformComponent = TransformComponent(
            entityId: ballEntityId!,
            position: ball.position,
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: SIMD3<Float>(1, 1, 1)
        )
        ecsWorld.componentManager.addComponent(ballTransformComponent, to: ballEntityId!)
        
        let ballGameEntityComponent = GameEntityComponent(
            entityId: ballEntityId!,
            entityType: .ball,
            isActive: true,
            isCollectable: false
        )
        ecsWorld.componentManager.addComponent(ballGameEntityComponent, to: ballEntityId!)
        
        // Create and setup cat
        let ballStartPosition = mazeService.getStartPosition()
        let catStartPosition = ballStartPosition + SIMD3<Float>(0.8, 0, 0) // Offset cat to the right of ball
        
        let (cat, catId) = entityFactory.createCatWithECS(
            componentManager: ecsWorld.componentManager,
            startPosition: catStartPosition,
            sleepDuration: gameConfiguration.catSleepDuration
        )
        
        catEntity = cat
        catEntityId = catId
        
        // Register cat with AI system
        if let aiSystem = ecsWorld.getSystem(AISystem.self) {
            aiSystem.registerEntity(cat, with: catId)
            aiSystem.setupChaseForCat(catEntityId: catId, targetEntityId: ballEntityId!)
        }
        
        // Register cat with render system
        if let renderSystem = ecsWorld.getSystem(RenderSystem.self) {
            renderSystem.registerEntity(cat, with: catId)
        }
        
        // Register cat with physics system
        if let physicsSystem = ecsWorld.getSystem(PhysicsSystem.self) {
            physicsSystem.registerEntity(cat, with: catId)
        }
        
        // Create camera
        let camera = cameraService.setupCamera(
            mazeSize: SIMD2<Int>(mazeService.maze.configuration.width, mazeService.maze.configuration.height),
            cellSize: mazeService.maze.configuration.cellSize
        )
        
        // Configure game service
        gameService.setBallEntity(ball)
        
        // Add to scene
        mazeWorld.addChild(ball)
        mazeWorld.addChild(cat)
        scene.addChild(mazeWorld)
        scene.addChild(camera)
        
        systemStatus = .ready
        print("🏗️ Game scene created successfully")
        
        return scene
    }
    
    /// Update the game coordinator (called from main game loop)
    func updateCoordinator(deltaTime: TimeInterval) {
        guard isRunning else { return }
        
        // Update ball position in ECS
        updateBallPosition()
        
        // Sync game state with ECS systems
        syncGameStateWithECS()
        
        // Check cat-player collision
        checkCatPlayerCollision()
        
        // Update ECS world
        ecsWorld.update(deltaTime: deltaTime)
        
        // Update services
        gameService.updateGameState()
        
        // Update performance metrics
        updatePerformanceMetrics()
    }
    
    /// Generate a new maze
    func generateNewMaze() {
        systemStatus = .initializing
        
        // Generate new maze
        _ = mazeService.generateMaze(
            width: gameConfiguration.maze.width,
            height: gameConfiguration.maze.height
        )
        
        systemStatus = .ready
        print("🌀 New maze generated")
    }
    
    /// Reset the game
    func resetGame() {
        gameService.resetGame()
        
        // Reset positions if scene exists
        if let scene = currentScene {
            resetEntityPositions(in: scene)
        }
        
        print("🔄 Game reset")
    }
    
    // MARK: - Private Methods
    
    private func handleGameStateChange(_ gameState: GameState) {
        switch gameState {
        case .playing:
            systemStatus = .running
        case .paused:
            systemStatus = .paused
        case .completed:
            systemStatus = .completed
            handleGameCompleted()
        case .failed:
            systemStatus = .failed
            handleGameFailed()
        case .menu:
            systemStatus = .ready
        }
    }
    
    private func handleInputChange(_ tiltData: TiltData) {
        // Coordinate input handling between services
        // This is where you could add input filtering, smoothing, etc.
        
        // The actual tilt application is handled in the GameViewModel
        // but we could add coordinator-level input processing here
    }
    
    private func handleMazeChange() {
        // Handle maze changes - could trigger scene recreation
        print("🔄 Maze changed - coordinator notified")
    }
    
    private func handleGameCompleted() {
        // Handle game completion logic
        // Could trigger achievements, leaderboards, etc.
        print("🎉 Game completed - coordinator handling")
    }
    
    private func handleGameFailed() {
        // Handle game failure logic
        // Could trigger retry prompts, analytics, etc.
        print("💥 Game failed - coordinator handling")
    }
    
    private func setupMazePhysics(entities: [Entity]) {
        for entity in entities {
            if entity.name.contains("Wall") {
                if let modelComponent = entity.components[ModelComponent.self] {
                    let boundingBox = modelComponent.mesh.bounds
                    let size = boundingBox.max - boundingBox.min
                    physicsService.setupWallPhysics(for: entity, size: size)
                }
            } else if entity.name.contains("Floor") {
                if let modelComponent = entity.components[ModelComponent.self] {
                    let boundingBox = modelComponent.mesh.bounds
                    let size = boundingBox.max - boundingBox.min
                    physicsService.setupFloorPhysics(for: entity, size: size)
                }
            }
        }
    }
    
    private func resetEntityPositions(in scene: Entity) {
        // Reset ball and cat positions (maze stays centered)
        scene.children.forEach { child in
            if child.name == "MazeWorld" {
                child.children.forEach { grandChild in
                    if grandChild.name == "MazeBall" {
                        grandChild.position = mazeService.getStartPosition()
                    } else if grandChild.name == "CatAgent" {
                        let ballStartPosition = mazeService.getStartPosition()
                        let catStartPosition = ballStartPosition + SIMD3<Float>(0.8, 0, 0) // Offset cat to the right of ball
                        grandChild.position = catStartPosition
                        
                        // Update cat's transform component and restart sleep
                        if let catEntityId = catEntityId,
                           var catTransform = ecsWorld.componentManager.getComponent(TransformComponent.self, for: catEntityId),
                           var catAI = ecsWorld.componentManager.getComponent(AIAgentComponent.self, for: catEntityId) {
                            catTransform.position = catStartPosition
                            catAI.startSleep() // Restart sleep when resetting
                            ecsWorld.componentManager.addComponent(catTransform, to: catEntityId)
                            ecsWorld.componentManager.addComponent(catAI, to: catEntityId)
                        }
                    }
                }
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Update performance metrics
        // Could track FPS, memory usage, etc.
    }
    
    /// Sync game state with ECS systems
    private func syncGameStateWithECS() {
        // Update GameLogicSystem with current game state
        if let gameLogicSystem = ecsWorld.getSystem(GameLogicSystem.self) {
            gameLogicSystem.setGameState(gameService.gameState)
        }
    }
    
    /// Update ball position in ECS for AI tracking
    private func updateBallPosition() {
        guard let ballEntityId = ballEntityId,
              let ballEntity = currentScene?.children.first(where: { $0.name == "MazeWorld" })?.children.first(where: { $0.name == "MazeBall" }) else { return }
        
        // Update ball's transform component with current position
        if var ballTransform = ecsWorld.componentManager.getComponent(TransformComponent.self, for: ballEntityId) {
            ballTransform.position = ballEntity.position
            ballTransform.rotation = ballEntity.transform.rotation
            ecsWorld.componentManager.addComponent(ballTransform, to: ballEntityId)
        }
    }
    
    /// Check if cat has caught the player
    private func checkCatPlayerCollision() {
        guard let catEntityId = catEntityId,
              let ballEntityId = ballEntityId,
              let aiSystem = ecsWorld.getSystem(AISystem.self) else { return }
        
        if aiSystem.checkCatPlayerCollision(catEntityId: catEntityId, playerEntityId: ballEntityId) {
            // Cat caught the player - game over
            gameService.setGameState(.failed)
            print("🐱 Cat caught the player! Game Over!")
        }
    }
    
    // MARK: - Service Access
    
    /// Get a specific service (for advanced use cases)
    func getInputService() -> InputService { return inputService }
    func getPhysicsService() -> PhysicsService { return physicsService }
    func getMazeService() -> MazeService { return mazeService }
    func getGameService() -> GameService { return gameService }
    func getCameraService() -> CameraService { return cameraService }
    func getEntityFactory() -> EntityFactory { return entityFactory }
    func getECSWorld() -> ECSWorld { return ecsWorld }
    
    // MARK: - Configuration
    
    /// Update game configuration
    func updateConfiguration(_ newConfiguration: GameConfiguration) {
        gameConfiguration = newConfiguration
        print("⚙️ Game configuration updated")
    }
    
    /// Get current configuration
    func getConfiguration() -> GameConfiguration {
        return gameConfiguration
    }
    
    // MARK: - Debug
    
    /// Get system status information
    func getSystemStatus() -> SystemStatusInfo {
        return SystemStatusInfo(
            coordinatorStatus: systemStatus,
            isInitialized: isInitialized,
            isRunning: isRunning,
            ecsSystemsCount: 5, // Number of ECS systems
            activeEntitiesCount: currentScene?.children.count ?? 0,
            gameState: gameService.gameState
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopCoordinator()
        cancellables.removeAll()
        print("🧹 GameCoordinator deallocated")
    }
}

// MARK: - System Status

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

struct SystemStatusInfo {
    let coordinatorStatus: SystemStatus
    let isInitialized: Bool
    let isRunning: Bool
    let ecsSystemsCount: Int
    let activeEntitiesCount: Int
    let gameState: GameState
}

// MARK: - Extensions

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
} 