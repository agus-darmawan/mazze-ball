import Foundation
import RealityKit
import SwiftUI
import Combine

/// Main ViewModel for the maze game following MVVM architecture
class GameViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var gameState: GameState = .menu
    @Published var score: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Services
    
    private let inputService: InputService
    private let physicsService: PhysicsService
    private let mazeService: MazeService
    private let gameService: GameService
    private let cameraService: CameraService
    private let entityFactory: EntityFactory
    
    // MARK: - ECS
    
    private let ecsWorld: ECSWorld
    
    // MARK: - Game Entities
    
    private var sceneEntity: Entity?
    private var mazeWorldEntity: Entity?
    private var ballEntity: Entity?
    private var cameraEntity: Entity?
    private var gameEntities: [Entity] = []
    
    // MARK: - Combine
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let gameConfiguration = GameConfiguration.default
    
    // MARK: - Initialization
    
    init() {
        // Initialize services
        self.inputService = InputService()
        self.physicsService = PhysicsService()
        self.mazeService = MazeService()
        self.gameService = GameService()
        self.cameraService = CameraService()
        self.entityFactory = EntityFactory()
        
        // Initialize ECS
        self.ecsWorld = ECSWorld()
        
        setupBindings()
        setupServices()
        
        print("🎮 GameViewModel initialized")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind game service state to view model
        gameService.$gameState
            .receive(on: DispatchQueue.main)
            .assign(to: \.gameState, on: self)
            .store(in: &cancellables)
        
        gameService.$score
            .receive(on: DispatchQueue.main)
            .assign(to: \.score, on: self)
            .store(in: &cancellables)
        
        // Bind input service to physics updates
        inputService.tiltData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tiltData in
                self?.handleTiltInput(tiltData)
            }
            .store(in: &cancellables)
        
        // Bind maze service changes
        mazeService.$maze
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMazeChanged()
            }
            .store(in: &cancellables)
    }
    
    private func setupServices() {
        // Setup service dependencies
        gameService.setMazeService(mazeService)
        
        // Initialize ECS world
        ecsWorld.initialize()
        
        print("🛠️ Services configured")
    }
    
    // MARK: - Public Methods
    
    /// Initialize the game scene
    func initializeScene() -> Entity {
        isLoading = true
        defer { isLoading = false }
        
        // Create main scene entity
        let scene = Entity()
        scene.name = "MazeScene"
        sceneEntity = scene
        
        // Create maze world container
        let mazeWorld = entityFactory.createContainer(name: "MazeWorld")
        mazeWorldEntity = mazeWorld
        
        // Generate maze entities
        let mazeEntities = mazeService.createMazeEntities()
        gameEntities = mazeEntities
        
        // Add maze entities to world
        for entity in mazeEntities {
            mazeWorld.addChild(entity)
        }
        
        // Setup physics for maze entities
        setupMazePhysics(entities: mazeEntities)
        
        // Create and setup ball
        let ball = entityFactory.createMazeBall()
        ballEntity = ball
        ball.position = mazeService.getStartPosition()
        
        // Setup ball physics
        physicsService.setupBallPhysics(for: ball, withMaterial: gameConfiguration.physicsMaterials.ball)
        
        // Create and setup camera
        let camera = cameraService.setupCamera(
            mazeSize: SIMD2<Int>(mazeService.maze.configuration.width, mazeService.maze.configuration.height),
            cellSize: mazeService.maze.configuration.cellSize
        )
        cameraEntity = camera
        
        // Configure game service
        gameService.setBallEntity(ball)
        
        // Add entities to scene
        mazeWorld.addChild(ball)
        scene.addChild(mazeWorld)
        scene.addChild(camera)
        
        print("🏗️ Scene initialized with \(mazeEntities.count) maze entities")
        return scene
    }
    
    /// Start the game
    func startGame() {
        inputService.startMonitoring()
        gameService.startGame()
        
        print("🎮 Game started")
    }
    
    /// Pause the game
    func pauseGame() {
        inputService.stopMonitoring()
        gameService.pauseGame()
        
        print("⏸️ Game paused")
    }
    
    /// Resume the game
    func resumeGame() {
        inputService.startMonitoring()
        gameService.resumeGame()
        
        print("▶️ Game resumed")
    }
    
    /// Reset the game
    func resetGame() {
        inputService.stopMonitoring()
        gameService.resetGame()
        
        // Reset ball position
        ballEntity?.position = mazeService.getStartPosition()
        
        print("🔄 Game reset")
    }
    
    /// Generate a new maze
    func generateNewMaze() {
        isLoading = true
        defer { isLoading = false }
        
        // Stop current game
        inputService.stopMonitoring()
        gameService.resetGame()
        
        // Generate new maze
        _ = mazeService.generateMaze(
            width: gameConfiguration.maze.width,
            height: gameConfiguration.maze.height
        )
        
        // Recreate scene will be handled by the maze changed binding
        print("🌀 New maze generated")
    }
    
    /// Update game (called from view's update loop)
    func updateGame(deltaTime: TimeInterval) {
        // Update ECS world
        ecsWorld.update(deltaTime: deltaTime)
        
        // Update game service
        gameService.updateGameState()
    }
    
    /// Handle view appearing
    func viewDidAppear() {
        // Start any necessary background services
        print("📱 View appeared")
    }
    
    /// Handle view disappearing
    func viewWillDisappear() {
        inputService.stopMonitoring()
        ecsWorld.shutdown()
        print("📱 View disappeared")
    }
    
    // MARK: - Private Methods
    
    private func handleTiltInput(_ tiltData: TiltData) {
        guard gameState == .playing,
              let ball = ballEntity else { return }
        
        // Apply tilt force only to the ball
        physicsService.applyTiltToBall(ball, tiltData: tiltData)
    }
    
    private func handleMazeChanged() {
        // Handle maze changes if needed
        // This could trigger scene recreation
        print("🔄 Maze changed - consider scene update")
    }
    
    private func setupMazePhysics(entities: [Entity]) {
        for entity in entities {
            if entity.name.contains("Wall") {
                // Get wall size from model component
                if let modelComponent = entity.components[ModelComponent.self] {
                    let boundingBox = modelComponent.mesh.bounds
                    let size = boundingBox.max - boundingBox.min
                    physicsService.setupWallPhysics(for: entity, size: size)
                }
            } else if entity.name.contains("Floor") {
                // Get floor size from model component
                if let modelComponent = entity.components[ModelComponent.self] {
                    let boundingBox = modelComponent.mesh.bounds
                    let size = boundingBox.max - boundingBox.min
                    physicsService.setupFloorPhysics(for: entity, size: size)
                }
            }
        }
    }
    
    // MARK: - Game Actions
    
    /// Handle game completion
    private func handleGameCompleted() {
        inputService.stopMonitoring()
        
        // Could trigger celebration effects, score saving, etc.
        print("🎉 Game completed!")
    }
    
    /// Handle game failure
    private func handleGameFailed() {
        inputService.stopMonitoring()
        
        // Could trigger failure effects, restart prompt, etc.
        print("💥 Game failed!")
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        print("❌ Error: \(error)")
    }
    
    // MARK: - Cleanup
    
    deinit {
        inputService.stopMonitoring()
        ecsWorld.shutdown()
        cancellables.removeAll()
        print("🧹 GameViewModel deallocated")
    }
}

// MARK: - Game State Helpers

extension GameViewModel {
    
    var isGameActive: Bool {
        return gameState == .playing
    }
    
    var isGamePaused: Bool {
        return gameState == .paused
    }
    
    var isGameCompleted: Bool {
        return gameState == .completed
    }
    
    var isGameFailed: Bool {
        return gameState == .failed
    }
    
    var canStartGame: Bool {
        return gameState == .menu || gameState == .failed
    }
    
    var canPauseGame: Bool {
        return gameState == .playing
    }
    
    var canResumeGame: Bool {
        return gameState == .paused
    }
}

// MARK: - Debug Information

extension GameViewModel {
    
    func getDebugInfo() -> String {
        var info = "=== Debug Info ===\n"
        info += "Game State: \(gameState)\n"
        info += "Score: \(score)\n"
        info += "Ball Position: \(ballEntity?.position ?? SIMD3<Float>(0, 0, 0))\n"
        info += "Maze Size: \(mazeService.maze.configuration.width)x\(mazeService.maze.configuration.height)\n"
        info += "Entities Count: \(gameEntities.count)\n"
        return info
    }
} 