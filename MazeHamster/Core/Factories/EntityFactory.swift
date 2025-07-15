import Foundation
import RealityKit
import simd

/// Concrete implementation of EntityFactory for centralized entity creation
class EntityFactory: EntityFactoryProtocol {
    
    // MARK: - Private Properties
    
    private let gameConfig = GameConfiguration.default
    private let visualMaterials = VisualMaterials.default
    private let physicsMaterials = PhysicsMaterials.default
    
    // MARK: - Protocol Methods
    
    func createBall(radius: Float, material: SimpleMaterial) -> Entity {
        let ball = Entity()
        ball.name = "MazeBall"
        
        // Create ball mesh
        let ballMesh = MeshResource.generateSphere(radius: radius)
        ball.components.set(ModelComponent(mesh: ballMesh, materials: [material]))
        
        // Add physics components
        let physicsBody = PhysicsBodyComponent(
            shapes: [.generateSphere(radius: radius)],
            mass: 1.0,
            material: physicsMaterials.ball,
            mode: .dynamic
        )
        
        let collision = CollisionComponent(
            shapes: [.generateSphere(radius: radius)]
        )
        
        ball.components.set(physicsBody)
        ball.components.set(collision)
        
        print("🎯 Ball entity created with radius: \(radius)")
        return ball
    }
    
    func createWall(size: SIMD3<Float>, material: SimpleMaterial) -> Entity {
        let wall = Entity()
        wall.name = "MazeWall"
        
        // Create wall mesh
        let wallMesh = MeshResource.generateBox(size: size)
        wall.components.set(ModelComponent(mesh: wallMesh, materials: [material]))
        
        // Add physics components for static wall
        let physicsBody = PhysicsBodyComponent(
            shapes: [.generateBox(size: size)],
            mass: 0.0,
            material: physicsMaterials.wall,
            mode: .static
        )
        
        let collision = CollisionComponent(
            shapes: [.generateBox(size: size)]
        )
        
        wall.components.set(physicsBody)
        wall.components.set(collision)
        
        print("🧱 Wall entity created with size: \(size)")
        return wall
    }
    
    func createFloor(size: SIMD3<Float>, material: SimpleMaterial) -> Entity {
        let floor = Entity()
        floor.name = "MazeFloor"
        
        // Create floor mesh
        let floorMesh = MeshResource.generateBox(size: size)
        floor.components.set(ModelComponent(mesh: floorMesh, materials: [material]))
        
        // Add physics components for static floor
        let physicsBody = PhysicsBodyComponent(
            shapes: [.generateBox(size: size)],
            mass: 0.0,
            material: physicsMaterials.floor,
            mode: .static
        )
        
        let collision = CollisionComponent(
            shapes: [.generateBox(size: size)]
        )
        
        floor.components.set(physicsBody)
        floor.components.set(collision)
        
        print("🏢 Floor entity created with size: \(size)")
        return floor
    }
    
    func createExit(radius: Float, material: SimpleMaterial) -> Entity {
        let exit = Entity()
        exit.name = "MazeExit"
        
        // Create exit mesh
        let exitMesh = MeshResource.generateSphere(radius: radius)
        exit.components.set(ModelComponent(mesh: exitMesh, materials: [material]))
        
        // Add trigger collision for exit detection
        let collision = CollisionComponent(
            shapes: [.generateSphere(radius: radius)]
        )
        
        exit.components.set(collision)
        
        print("🚪 Exit entity created with radius: \(radius)")
        return exit
    }
    
    // MARK: - Extended Factory Methods
    
    /// Create a complete maze ball with default settings
    func createMazeBall() -> Entity {
        return createBall(
            radius: gameConfig.ballRadius,
            material: visualMaterials.ball
        )
    }
    
    /// Create a wall at specific position with automatic positioning
    func createWallAt(position: SIMD3<Float>, size: SIMD3<Float>) -> Entity {
        let wall = createWall(size: size, material: visualMaterials.wall)
        wall.position = position + SIMD3<Float>(0, size.y * 0.5, 0) // Raise wall to sit on floor
        return wall
    }
    
    /// Create a floor with automatic centering
    func createFloorAt(center: SIMD3<Float>, size: SIMD3<Float>) -> Entity {
        let floor = createFloor(size: size, material: visualMaterials.floor)
        floor.position = center.offsetY(-0.05) // Slightly below ground level
        return floor
    }
    
    /// Create an exit with default settings
    func createMazeExit() -> Entity {
        return createExit(
            radius: gameConfig.exitRadius,
            material: visualMaterials.exit
        )
    }
    
    /// Create a light entity for scene illumination
    func createLight(type: LightType = .directional, intensity: Float = 1000) -> Entity {
        let light = Entity()
        light.name = "SceneLight"
        
        switch type {
        case .directional:
            var directionalLight = DirectionalLightComponent()
            directionalLight.color = .white
            directionalLight.intensity = intensity
            directionalLight.isRealWorldProxy = false
            light.components.set(directionalLight)
            
        case .point:
            var pointLight = PointLightComponent()
            pointLight.color = .white
            pointLight.intensity = intensity
            pointLight.attenuationRadius = 10.0
            light.components.set(pointLight)
            
        case .spot:
            var spotLight = SpotLightComponent()
            spotLight.color = .white
            spotLight.intensity = intensity
            spotLight.attenuationRadius = 10.0
            spotLight.innerAngleInDegrees = 30
            spotLight.outerAngleInDegrees = 45
            light.components.set(spotLight)
        }
        
        print("💡 Light entity created with type: \(type)")
        return light
    }
    
    /// Create a camera entity
    func createCamera(fov: Float = 45.0) -> Entity {
        let camera = Entity()
        camera.name = "GameCamera"
        
        var cameraComponent = PerspectiveCameraComponent()
        cameraComponent.near = 1.0
        cameraComponent.far = 1000.0
        cameraComponent.fieldOfViewInDegrees = fov
        camera.components.set(cameraComponent)
        
        print("📷 Camera entity created with FOV: \(fov)°")
        return camera
    }
    
    /// Create a container entity for grouping related entities
    func createContainer(name: String) -> Entity {
        let container = Entity()
        container.name = name
        
        print("📦 Container entity created: \(name)")
        return container
    }
    
    /// Create a particle system entity (for effects)
    func createParticleSystem(name: String) -> Entity {
        let particles = Entity()
        particles.name = name
        
        // Note: Particle systems would be configured based on specific needs
        // This is a placeholder for particle system creation
        
        print("✨ Particle system entity created: \(name)")
        return particles
    }
    
    // MARK: - Helper Methods
    
    /// Apply common transformations to an entity
    func applyTransform(to entity: Entity, position: SIMD3<Float>, rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) {
        entity.position = position
        entity.transform.rotation = rotation
        entity.transform.scale = scale
    }
    
    /// Set entity visibility
    func setVisibility(of entity: Entity, isVisible: Bool) {
        entity.isEnabled = isVisible
    }
    
    /// Clone an existing entity
    func cloneEntity(_ entity: Entity, withName name: String) -> Entity {
        let clone = entity.clone(recursive: true)
        clone.name = name
        
        print("🔄 Entity cloned: \(name)")
        return clone
    }
    
    /// Remove entity from scene
    func removeEntity(_ entity: Entity) {
        entity.removeFromParent()
        print("🗑️ Entity removed: \(entity.name)")
    }
}

// MARK: - Light Types

enum LightType {
    case directional
    case point
    case spot
}

// MARK: - Entity Extensions for Factory

extension Entity {
    /// Convenience method to set entity name with fluent interface
    func withName(_ name: String) -> Entity {
        self.name = name
        return self
    }
    
    /// Convenience method to set entity position with fluent interface
    func withPosition(_ position: SIMD3<Float>) -> Entity {
        self.position = position
        return self
    }
    
    /// Convenience method to set entity rotation with fluent interface
    func withRotation(_ rotation: simd_quatf) -> Entity {
        self.transform.rotation = rotation
        return self
    }
    
    /// Convenience method to set entity scale with fluent interface
    func withScale(_ scale: SIMD3<Float>) -> Entity {
        self.transform.scale = scale
        return self
    }
} 