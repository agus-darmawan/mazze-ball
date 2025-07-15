import Foundation
import RealityKit
import simd

// MARK: - ECS Component Protocol

/// Base protocol for all ECS components
protocol GameComponent {
    var entityId: UUID { get }
}

// MARK: - Core Components

/// Component for tracking entity transform data
struct TransformComponent: GameComponent {
    let entityId: UUID
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>
    
    init(entityId: UUID, position: SIMD3<Float> = SIMD3<Float>(0, 0, 0), rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) {
        self.entityId = entityId
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

/// Component for physics properties
struct PhysicsComponent: GameComponent {
    let entityId: UUID
    var mass: Float
    var physicsMaterial: PhysicsMaterialResource
    var bodyMode: PhysicsBodyMode
    var shapes: [ShapeResource]
    
    init(entityId: UUID, mass: Float = 1.0, physicsMaterial: PhysicsMaterialResource, bodyMode: PhysicsBodyMode = .dynamic, shapes: [ShapeResource]) {
        self.entityId = entityId
        self.mass = mass
        self.physicsMaterial = physicsMaterial
        self.bodyMode = bodyMode
        self.shapes = shapes
    }
}

/// Component for collision detection
struct GameCollisionComponent: GameComponent {
    let entityId: UUID
    var shapes: [ShapeResource]
    var isStatic: Bool
    var isTrigger: Bool
    
    init(entityId: UUID, shapes: [ShapeResource], isStatic: Bool = false, isTrigger: Bool = false) {
        self.entityId = entityId
        self.shapes = shapes
        self.isStatic = isStatic
        self.isTrigger = isTrigger
    }
}

/// Component for visual rendering
struct RenderComponent: GameComponent {
    let entityId: UUID
    var mesh: MeshResource
    var materials: [Material]
    var isVisible: Bool
    
    init(entityId: UUID, mesh: MeshResource, materials: [Material], isVisible: Bool = true) {
        self.entityId = entityId
        self.mesh = mesh
        self.materials = materials
        self.isVisible = isVisible
    }
}

/// Component for input handling
struct InputComponent: GameComponent {
    let entityId: UUID
    var isControllable: Bool
    var inputSensitivity: Float
    
    init(entityId: UUID, isControllable: Bool = false, inputSensitivity: Float = 1.0) {
        self.entityId = entityId
        self.isControllable = isControllable
        self.inputSensitivity = inputSensitivity
    }
}

/// Component for game entities (ball, walls, etc.)
struct GameEntityComponent: GameComponent {
    let entityId: UUID
    var entityType: GameEntityType
    var isActive: Bool
    var isCollectable: Bool
    
    init(entityId: UUID, entityType: GameEntityType, isActive: Bool = true, isCollectable: Bool = false) {
        self.entityId = entityId
        self.entityType = entityType
        self.isActive = isActive
        self.isCollectable = isCollectable
    }
}

// CameraComponent removed - using simplified fixed camera approach

// MARK: - Game Entity Types

enum GameEntityType {
    case ball
    case wall
    case floor
    case exit
    case maze
    case camera
    case light
}

// MARK: - Component Storage

/// ECS Component manager for storing and retrieving components
class ComponentManager: ObservableObject {
    private var components: [String: [UUID: Any]] = [:]
    
    /// Add a component to an entity
    func addComponent<T: GameComponent>(_ component: T, to entityId: UUID) {
        let componentType = String(describing: T.self)
        if components[componentType] == nil {
            components[componentType] = [:]
        }
        components[componentType]?[entityId] = component
    }
    
    /// Get a component from an entity
    func getComponent<T: GameComponent>(_ type: T.Type, for entityId: UUID) -> T? {
        let componentType = String(describing: type)
        return components[componentType]?[entityId] as? T
    }
    
    /// Remove a component from an entity
    func removeComponent<T: GameComponent>(_ type: T.Type, from entityId: UUID) {
        let componentType = String(describing: type)
        components[componentType]?.removeValue(forKey: entityId)
    }
    
    /// Check if entity has a specific component
    func hasComponent<T: GameComponent>(_ type: T.Type, for entityId: UUID) -> Bool {
        let componentType = String(describing: type)
        return components[componentType]?[entityId] != nil
    }
    
    /// Get all entities with a specific component
    func getAllEntitiesWithComponent<T: GameComponent>(_ type: T.Type) -> [UUID] {
        let componentType = String(describing: type)
        guard let componentDict = components[componentType] else { return [] }
        return Array(componentDict.keys)
    }
    
    /// Remove all components for an entity
    func removeAllComponents(for entityId: UUID) {
        for componentType in components.keys {
            components[componentType]?.removeValue(forKey: entityId)
        }
    }
} 