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
    private var catEntity: Entity?
    private var catEntityId: UUID?
    private var ballEntityId: UUID?
    
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
        mazeWorld.addChild(cat)
        scene.addChild(mazeWorld)
        scene.addChild(camera)
        
        // Auto-start the game so AI can begin working
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startGame()
        }
        
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
        
        // Reset cat position and sleep state
        resetCatPosition()
        
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
        // Update ball position in ECS for AI tracking
        updateBallPositionForAI()
        
        // Sync game state with ECS systems
        syncGameStateWithECS()
        
        // Check cat-player collision
        checkCatPlayerCollision()
        
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
    
    // MARK: - Private Helper Methods
    
    /// Update ball position in ECS for AI tracking
    private func updateBallPositionForAI() {
        guard let ballEntityId = ballEntityId,
              let ballEntity = ballEntity else { return }
        
        // Update ball's transform component with current position
        if var ballTransform = ecsWorld.componentManager.getComponent(TransformComponent.self, for: ballEntityId) {
            ballTransform.position = ballEntity.position
            ballTransform.rotation = ballEntity.transform.rotation
            ecsWorld.componentManager.addComponent(ballTransform, to: ballEntityId)
            
            // Debug print for ball position updates
            if abs(ballTransform.position.x) > 0.1 || abs(ballTransform.position.z) > 0.1 {
                print("🎯 Ball position updated: \(ballTransform.position)")
            }
        }
    }
    
    /// Sync game state with ECS systems
    private func syncGameStateWithECS() {
        // Update GameLogicSystem with current game state
        if let gameLogicSystem = ecsWorld.getSystem(GameLogicSystem.self) {
            gameLogicSystem.setGameState(gameState)
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
    
    /// Reset cat position and sleep state
    private func resetCatPosition() {
        guard let catEntityId = catEntityId,
              let catEntity = catEntity else { return }
        
        let ballStartPosition = mazeService.getStartPosition()
        let catStartPosition = ballStartPosition + SIMD3<Float>(0.8, 0, 0) // Offset cat to the right of ball
        catEntity.position = catStartPosition
        
        // Update cat's transform component and restart sleep
        if var catTransform = ecsWorld.componentManager.getComponent(TransformComponent.self, for: catEntityId),
           var catAI = ecsWorld.componentManager.getComponent(AIAgentComponent.self, for: catEntityId) {
            catTransform.position = catStartPosition
            catAI.startSleep() // Restart sleep when resetting
            ecsWorld.componentManager.addComponent(catTransform, to: catEntityId)
            ecsWorld.componentManager.addComponent(catAI, to: catEntityId)
        }
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