import Foundation
import RealityKit
import simd
import CoreMotion

// MARK: - ECS System Protocol

/// Base protocol for all ECS systems
protocol GameSystem {
    var componentManager: ComponentManager { get }
    func update(deltaTime: TimeInterval)
    func initialize()
    func shutdown()
}

// MARK: - Core Systems

/// System for handling physics updates
class PhysicsSystem: GameSystem {
    let componentManager: ComponentManager
    private var realityEntities: [UUID: Entity] = [:]
    
    init(componentManager: ComponentManager) {
        self.componentManager = componentManager
    }
    
    func initialize() {
        // Initialize physics world settings
    }
    
    func update(deltaTime: TimeInterval) {
        let physicsEntities = componentManager.getAllEntitiesWithComponent(PhysicsComponent.self)
        
        for entityId in physicsEntities {
            guard let physicsComponent = componentManager.getComponent(PhysicsComponent.self, for: entityId),
                  let transformComponent = componentManager.getComponent(TransformComponent.self, for: entityId),
                  let realityEntity = realityEntities[entityId] else { continue }
            
            // Update RealityKit entity physics from component
            if let physicsBody = realityEntity.components[PhysicsBodyComponent.self] {
                // Sync component data to RealityKit
                realityEntity.position = transformComponent.position
                realityEntity.transform.rotation = transformComponent.rotation
            }
        }
    }
    
    func shutdown() {
        realityEntities.removeAll()
    }
    
    /// Register a RealityKit entity with the physics system
    func registerEntity(_ entity: Entity, with entityId: UUID) {
        realityEntities[entityId] = entity
    }
    
    /// Apply physics forces to an entity
    func applyForce(_ force: SIMD3<Float>, to entityId: UUID) {
        guard let realityEntity = realityEntities[entityId],
              realityEntity.components[PhysicsBodyComponent.self] != nil else { return }
        
        // Apply force to RealityKit entity by modifying transform
        let currentTransform = realityEntity.transform
        let newPosition = currentTransform.translation + force * 0.016 // Assuming 60fps
        realityEntity.move(to: Transform(scale: currentTransform.scale, rotation: currentTransform.rotation, translation: newPosition), 
                          relativeTo: realityEntity.parent)
    }
}

/// System for handling input and motion
class InputSystem: GameSystem {
    let componentManager: ComponentManager
    private var motionManager = CMMotionManager()
    private var currentTiltData: TiltData?
    
    init(componentManager: ComponentManager) {
        self.componentManager = componentManager
    }
    
    func initialize() {
        startMotionUpdates()
    }
    
    func update(deltaTime: TimeInterval) {
        guard let tiltData = currentTiltData else { return }
        
        let inputEntities = componentManager.getAllEntitiesWithComponent(InputComponent.self)
        
        for entityId in inputEntities {
            guard let inputComponent = componentManager.getComponent(InputComponent.self, for: entityId),
                  inputComponent.isControllable else { continue }
            
            // Process input for controllable entities
            processInputForEntity(entityId, tiltData: tiltData)
        }
    }
    
    func shutdown() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            let gravity = motion.gravity
            let roll = Float(atan2(gravity.x, sqrt(gravity.y * gravity.y + gravity.z * gravity.z)))
            let pitch = Float(atan2(gravity.y, sqrt(gravity.x * gravity.x + gravity.z * gravity.z)))
            
            self.currentTiltData = TiltData(roll: roll, pitch: pitch)
        }
    }
    
    private func processInputForEntity(_ entityId: UUID, tiltData: TiltData) {
        guard let inputComponent = componentManager.getComponent(InputComponent.self, for: entityId) else { return }
        
        // Apply input sensitivity
        let adjustedTiltData = TiltData(
            roll: tiltData.roll * inputComponent.inputSensitivity,
            pitch: tiltData.pitch * inputComponent.inputSensitivity
        )
        
        // Update transform component based on input
        if var transformComponent = componentManager.getComponent(TransformComponent.self, for: entityId) {
            transformComponent.rotation = adjustedTiltData.quaternion
            componentManager.addComponent(transformComponent, to: entityId)
        }
    }
}

/// System for handling rendering updates
class RenderSystem: GameSystem {
    let componentManager: ComponentManager
    private var realityEntities: [UUID: Entity] = [:]
    
    init(componentManager: ComponentManager) {
        self.componentManager = componentManager
    }
    
    func initialize() {
        // Initialize rendering settings
    }
    
    func update(deltaTime: TimeInterval) {
        let renderEntities = componentManager.getAllEntitiesWithComponent(RenderComponent.self)
        
        for entityId in renderEntities {
            guard let renderComponent = componentManager.getComponent(RenderComponent.self, for: entityId),
                  let transformComponent = componentManager.getComponent(TransformComponent.self, for: entityId),
                  let realityEntity = realityEntities[entityId] else { continue }
            
            // Update RealityKit entity rendering from component
            realityEntity.position = transformComponent.position
            realityEntity.transform.rotation = transformComponent.rotation
            realityEntity.transform.scale = transformComponent.scale
            realityEntity.isEnabled = renderComponent.isVisible
        }
    }
    
    func shutdown() {
        realityEntities.removeAll()
    }
    
    /// Register a RealityKit entity with the render system
    func registerEntity(_ entity: Entity, with entityId: UUID) {
        realityEntities[entityId] = entity
    }
}

/// System for handling game logic
class GameLogicSystem: GameSystem {
    let componentManager: ComponentManager
    private var gameState: GameState = .menu
    
    init(componentManager: ComponentManager) {
        self.componentManager = componentManager
    }
    
    func initialize() {
        gameState = .menu
    }
    
    func update(deltaTime: TimeInterval) {
        // Update game logic based on current state
        switch gameState {
        case .playing:
            updateGameplay(deltaTime: deltaTime)
        case .paused:
            // Handle pause state
            break
        case .completed:
            // Handle completion state
            break
        case .failed:
            // Handle failure state
            break
        case .menu:
            // Handle menu state
            break
        }
    }
    
    func shutdown() {
        // Clean up game logic
    }
    
    private func updateGameplay(deltaTime: TimeInterval) {
        // Check for win conditions, collisions, etc.
        checkWinCondition()
        checkCollisions()
    }
    
    private func checkWinCondition() {
        // Check if ball has reached the exit
        let ballEntities = componentManager.getAllEntitiesWithComponent(GameEntityComponent.self)
            .filter { entityId in
                guard let gameEntity = componentManager.getComponent(GameEntityComponent.self, for: entityId) else { return false }
                return gameEntity.entityType == .ball
            }
        
        let exitEntities = componentManager.getAllEntitiesWithComponent(GameEntityComponent.self)
            .filter { entityId in
                guard let gameEntity = componentManager.getComponent(GameEntityComponent.self, for: entityId) else { return false }
                return gameEntity.entityType == .exit
            }
        
        // Check distance between ball and exit
        for ballId in ballEntities {
            for exitId in exitEntities {
                guard let ballTransform = componentManager.getComponent(TransformComponent.self, for: ballId),
                      let exitTransform = componentManager.getComponent(TransformComponent.self, for: exitId) else { continue }
                
                let distance = simd_distance(ballTransform.position, exitTransform.position)
                if distance < 0.5 { // Within exit radius
                    gameState = .completed
                    return
                }
            }
        }
    }
    
    private func checkCollisions() {
        // Handle collision detection and response
        // This would integrate with RealityKit's collision system
    }
    
    /// Get current game state
    func getCurrentGameState() -> GameState {
        return gameState
    }
    
    /// Set game state
    func setGameState(_ newState: GameState) {
        gameState = newState
    }
}

// CameraSystem removed - using simplified fixed camera approach

// MARK: - ECS World

/// Main ECS world that manages all systems and components
class ECSWorld: ObservableObject {
    let componentManager = ComponentManager()
    private var systems: [GameSystem] = []
    private var isRunning = false
    
    init() {
        setupSystems()
    }
    
    private func setupSystems() {
        systems = [
            PhysicsSystem(componentManager: componentManager),
            InputSystem(componentManager: componentManager),
            RenderSystem(componentManager: componentManager),
            GameLogicSystem(componentManager: componentManager)
        ]
    }
    
    /// Initialize all systems
    func initialize() {
        for system in systems {
            system.initialize()
        }
        isRunning = true
    }
    
    /// Update all systems
    func update(deltaTime: TimeInterval) {
        guard isRunning else { return }
        
        for system in systems {
            system.update(deltaTime: deltaTime)
        }
    }
    
    /// Shutdown all systems
    func shutdown() {
        for system in systems {
            system.shutdown()
        }
        isRunning = false
    }
    
    /// Get a specific system
    func getSystem<T: GameSystem>(_ type: T.Type) -> T? {
        return systems.first { $0 is T } as? T
    }
} 
