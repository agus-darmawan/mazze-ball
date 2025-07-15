import Foundation
import RealityKit
import simd
import CoreMotion
import GameplayKit

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
            guard let _ = componentManager.getComponent(PhysicsComponent.self, for: entityId),
                  let transformComponent = componentManager.getComponent(TransformComponent.self, for: entityId),
                  let realityEntity = realityEntities[entityId] else { continue }
            
            // Update RealityKit entity physics from component
            if realityEntity.components[PhysicsBodyComponent.self] != nil {
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

/// System for handling AI agent behavior
class AISystem: GameSystem {
    let componentManager: ComponentManager
    private var realityEntities: [UUID: Entity] = [:]
    private var agentSystem: GKComponentSystem<GKAgent3D>
    
    init(componentManager: ComponentManager) {
        self.componentManager = componentManager
        self.agentSystem = GKComponentSystem(componentClass: GKAgent3D.self)
    }
    
    func initialize() {
        // Initialize AI system settings
        print("🤖 AI System initialized")
    }
    
    func update(deltaTime: TimeInterval) {
        let aiEntities = componentManager.getAllEntitiesWithComponent(AIAgentComponent.self)
        
        if !aiEntities.isEmpty {
            print("🤖 AI System updating \(aiEntities.count) entities")
        }
        
        for entityId in aiEntities {
            guard var aiComponent = componentManager.getComponent(AIAgentComponent.self, for: entityId),
                  let transformComponent = componentManager.getComponent(TransformComponent.self, for: entityId) else { continue }
            
            // Handle sleep state
            if aiComponent.isSleeping {
                if aiComponent.isSleepFinished() {
                    // Wake up and start chasing
                    aiComponent.wakeUp()
                    componentManager.addComponent(aiComponent, to: entityId)
                    print("🐱 Cat \(entityId) woke up and started chasing!")
                } else {
                    // Still sleeping, skip AI processing
                    print("😴 Cat \(entityId) is still sleeping...")
                    continue
                }
            }
            
            // Update agent position from transform (current cat position)
            let agent = aiComponent.agent
            let currentPosition = transformComponent.position
            agent.position = vector_float3(currentPosition)
            
            // Update target position if we have a target
            if let targetId = aiComponent.targetEntityId,
               let targetTransform = componentManager.getComponent(TransformComponent.self, for: targetId) {
                let targetPosition = targetTransform.position
                let distance = simd_distance(currentPosition, targetPosition)
                
                print("🎯 Cat \(entityId) at \(currentPosition) chasing target at \(targetPosition), distance: \(distance)")
                
                updateChaseTarget(for: entityId, targetPosition: targetPosition)
            } else {
                print("⚠️ Cat \(entityId) has no target entity!")
            }
            
            // Update agent behavior
            agentSystem.update(deltaTime: deltaTime)
            
            // Apply agent movement to transform
            applyAgentMovement(for: entityId, agent: agent)
        }
    }
    
    func shutdown() {
        realityEntities.removeAll()
        print("🤖 AI System shut down")
    }
    
    /// Register a RealityKit entity with the AI system
    func registerEntity(_ entity: Entity, with entityId: UUID) {
        realityEntities[entityId] = entity
    }
    
    /// Set up chase behavior for a cat entity
    func setupChaseForCat(catEntityId: UUID, targetEntityId: UUID) {
        guard var aiComponent = componentManager.getComponent(AIAgentComponent.self, for: catEntityId) else { return }
        
        // Set the target
        aiComponent.targetEntityId = targetEntityId
        
        // Start the cat in sleeping state
        aiComponent.startSleep()
        
        // Create chase goal (will be used when cat wakes up)
        let seekGoal = GKGoal(toSeekAgent: aiComponent.agent)
        
        // Create behavior with the goal
        let behavior = GKBehavior()
        behavior.setWeight(1.0, for: seekGoal)
        
        // Update the component
        aiComponent.behavior = behavior
        aiComponent.agent.behavior = behavior
        
        // Add agent to system
        agentSystem.addComponent(aiComponent.agent)
        
        // Update the component in the manager
        componentManager.addComponent(aiComponent, to: catEntityId)
        
        print("🐱 Chase behavior set up for cat entity - starting sleep for \(aiComponent.sleepDuration) seconds")
    }
    
    /// Update the chase target position
    private func updateChaseTarget(for entityId: UUID, targetPosition: SIMD3<Float>) {
        guard var aiComponent = componentManager.getComponent(AIAgentComponent.self, for: entityId) else { return }
        
        // Update last known target position
        aiComponent.lastKnownTargetPosition = targetPosition
        
        // Create a properly configured target agent
        let targetAgent = GKAgent3D()
        targetAgent.position = vector_float3(targetPosition)
        targetAgent.radius = 0.2  // Ball radius
        targetAgent.mass = 1.0
        targetAgent.maxSpeed = 0.1
        targetAgent.maxAcceleration = 0.1
        
        // Create seek goal with proper weight
        let seekGoal = GKGoal(toSeekAgent: targetAgent)
        
        // Create new behavior with seek goal
        let behavior = GKBehavior()
        behavior.setWeight(1.0, for: seekGoal)  // Start with normal weight
        
        // Update the agent's behavior
        aiComponent.behavior = behavior
        aiComponent.agent.behavior = behavior
        
        // Debug agent configuration
        let agent = aiComponent.agent
        print("🤖 Agent config - Position: \(agent.position), MaxSpeed: \(agent.maxSpeed), MaxAccel: \(agent.maxAcceleration)")
        print("🎯 Target agent - Position: \(targetAgent.position)")
        
        // Update the component
        componentManager.addComponent(aiComponent, to: entityId)
        
        print("🎯 Updated chase target for cat \(entityId) to position: \(targetPosition)")
    }
    
    /// Apply agent movement to transform component using physics forces
    private func applyAgentMovement(for entityId: UUID, agent: GKAgent3D) {
        guard var transformComponent = componentManager.getComponent(TransformComponent.self, for: entityId),
              let realityEntity = realityEntities[entityId] else { 
            print("⚠️ Could not get transform component or reality entity for cat \(entityId)")
            return 
        }
        
        // Get the desired velocity from the agent
        let desiredVelocity = SIMD3<Float>(agent.velocity.x, agent.velocity.y, agent.velocity.z)
        let velocityMagnitude = length(desiredVelocity)
        
        // Apply movement through RealityKit physics system
        if realityEntity.components[PhysicsBodyComponent.self] != nil {
            let currentPosition = realityEntity.position
            
            // Debug information
            if velocityMagnitude > 0.001 {
                print("🐱 Cat \(entityId) - Current: \(currentPosition), Velocity: \(desiredVelocity), Magnitude: \(velocityMagnitude)")
            }
            
            // Apply movement if there's significant velocity
            if velocityMagnitude > 0.001 {
                // Apply the GameplayKit velocity directly but scaled down
                let moveSpeed: Float = 0.016  // Frame time (60fps)
                let movement = desiredVelocity * moveSpeed
                
                // Calculate new position
                let newPosition = currentPosition + movement
                
                // Update the entity position - RealityKit physics will handle collision
                realityEntity.position = newPosition
                
                print("🐱 Cat \(entityId) moved from \(currentPosition) to \(newPosition)")
            } else {
                print("🐱 Cat \(entityId) has no significant velocity, not moving")
            }
        }
        
        // Update transform component with current position (don't override physics)
        transformComponent.position = realityEntity.position
        componentManager.addComponent(transformComponent, to: entityId)
    }
    
    /// Check if cat has caught the player
    func checkCatPlayerCollision(catEntityId: UUID, playerEntityId: UUID) -> Bool {
        guard let catTransform = componentManager.getComponent(TransformComponent.self, for: catEntityId),
              let playerTransform = componentManager.getComponent(TransformComponent.self, for: playerEntityId) else { return false }
        
        let distance = simd_distance(catTransform.position, playerTransform.position)
        let collisionDistance: Float = 0.5 // Adjust based on entity sizes
        
        return distance < collisionDistance
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
            GameLogicSystem(componentManager: componentManager),
            AISystem(componentManager: componentManager)
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
