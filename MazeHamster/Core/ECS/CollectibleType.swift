//
//  CollectibleSystem.swift
//  MazeBall
//
//  Maze Feature: Collectible Items System
//

import Foundation
import RealityKit
import simd
import SwiftUI


// MARK: - Collectible Types

enum CollectibleType: CaseIterable {
    case coin           // Basic points
    case shield         // Temporary cat protection
    case fish           // biar kucingnya tambah cepat
    case pillow         // stunt kucing yes
    case bubbleGum      // melambatkan si hamster
    
    var points: Int {
        switch self {
        case .coin: return 10
        case .shield: return 0
        case .fish: return 0
        case .pillow: return 0
        case .bubbleGum: return 0
        }
    }
    
    var color: UIColor {
        switch self {
        case .coin: return .systemYellow
        case .shield: return .systemGreen
        case .fish: return .systemRed
        case .pillow: return .systemBlue
        case .bubbleGum: return .systemOrange
        }
    }
    
    var effectDuration: TimeInterval {
        switch self {
        case .coin: return 0
        case .shield: return 7.0
        case .fish: return 7.0 // Durasi efek untuk ikan (mempercepat kucing)
        case .pillow: return 3.5 //durasi kucing tidur (stunt)
        case .bubbleGum: return 3.5 //durasi brp lama hamster melambat
        }
    }
    
    var rarity: Float {
        switch self {
        case .coin: return 0.9      // Common
        case .shield: return 0.2   // Uncommon
        case .fish: return 0.05    // Lebih jarang muncul karena membuat kucing lebih cepat (debuff)
        case .pillow: return 0.15
        case .bubbleGum: return 0.4
        }
    }
}

// MARK: - Collectible Component

struct CollectibleComponent: GameComponent {
    let entityId: UUID
    let collectibleType: CollectibleType
    var isCollected: Bool = false
    var pulseAnimation: Float = 0.0
    var rotationSpeed: Float = 2.0
    
    init(entityId: UUID, type: CollectibleType) {
        self.entityId = entityId
        self.collectibleType = type
    }
}

// MARK: - Player Status Component (Hamster)

struct PlayerStatusComponent: GameComponent {
    let entityId: UUID
    var hasSpeedBoost: Bool = false
    var hasShield: Bool = false
    var isSlowMotion: Bool = false
    var collectedKeys: Int = 0
    var totalCollectibles: Int = 0
    
    // Effect timers
    var speedBoostEndTime: Date?
    var shieldEndTime: Date?
    var slowMotionEndTime: Date?
    
    init(entityId: UUID) {
        self.entityId = entityId
    }
    
    // NOTE: Logika penerapan efek (yang memengaruhi entitas lain) DIPINDAHKAN ke CollectibleSystem
    // PlayerStatusComponent hanya akan mengupdate status internalnya sendiri.
    mutating func updateEffects() {
        let now = Date()
        
        if let endTime = speedBoostEndTime, now > endTime {
            hasSpeedBoost = false
            speedBoostEndTime = nil
        }
        
        if let endTime = shieldEndTime, now > endTime {
            hasShield = false
            shieldEndTime = nil
        }
        
        if let endTime = slowMotionEndTime, now > endTime {
            isSlowMotion = false
            slowMotionEndTime = nil
        }
    }
    
    var activeEffectsDescription: String {
        var effects: [String] = []
        if hasSpeedBoost { effects.append("🚀 Speed Boost") }
        if hasShield { effects.append("🛡️ Shield") }
        if isSlowMotion { effects.append("⏰ Slow Motion") }
        if collectedKeys > 0 { effects.append("🗝️ Keys: \(collectedKeys)") }
        
        return effects.isEmpty ? "None" : effects.joined(separator: ", ")
    }
}

// MARK: - Cat Status Component (Baru/Diperbaiki)

// Membuat komponen terpisah untuk status kucing agar lebih jelas
struct CatStatusComponent: GameComponent {
    let entityId: UUID
    var isStunned: Bool = false // Contoh efek stun
    var isSpeedBoosted: Bool = false // Untuk efek ikan
    var speedMultiplier: Float = 1.0 // Pengganda kecepatan default
    
    var stunEndTime: Date?
    var speedBoostEndTime: Date?
    
    init(entityId: UUID) {
        self.entityId = entityId
    }
    
    mutating func updateEffects() {
        let now = Date()
        
        if let endTime = stunEndTime, now > endTime {
            isStunned = false
            stunEndTime = nil
        }
        
        if let endTime = speedBoostEndTime, now > endTime {
            isSpeedBoosted = false
            speedBoostEndTime = nil
            speedMultiplier = 1.0 // Reset multiplier saat efek berakhir
        }
    }
}


// MARK: - Collectible System

class CollectibleSystem: GameSystem {
    let componentManager: ComponentManager
    private var realityEntities: [UUID: Entity] = [:]
    private var gameService: GameService?
    private var requiredKeysForExit: Int = 1
    // Tidak lagi menyimpan referensi langsung ke GameCoordinator di sini
    // private var gameScene: GameCoordinator? // Hapus ini

    // Tambahkan properti untuk ID entitas kucing dan hamster, yang akan disuntikkan dari GameCoordinator
    var catEntityId: UUID?
    var playerEntityId: UUID?
    
    init(componentManager: ComponentManager) {
        self.componentManager = componentManager
    }
    
    func initialize() {
        print("✨ CollectibleSystem initialized")
    }
    
    func update(deltaTime: TimeInterval) {
        updateCollectibleAnimations(deltaTime: deltaTime)
        updatePlayerEffects()
        updateCatEffects() // Panggil pembaruan efek kucing
        checkCollisions()
    }
    
    func shutdown() {
        realityEntities.removeAll()
        print("✨ CollectibleSystem shut down")
    }
    
    // MARK: - Animation Updates
    
    private func updateCollectibleAnimations(deltaTime: TimeInterval) {
        let collectibleEntities = componentManager.getAllEntitiesWithComponent(CollectibleComponent.self)
        
        for entityId in collectibleEntities {
            guard var collectible = componentManager.getComponent(CollectibleComponent.self, for: entityId),
                  !collectible.isCollected,
                  let realityEntity = realityEntities[entityId] else { continue }
            
            // Update pulse animation
            collectible.pulseAnimation += Float(deltaTime) * 3.0
            let pulseScale = 1.0 + sin(collectible.pulseAnimation) * 0.2
            
            // Update rotation
            let rotationAmount = Float(deltaTime) * collectible.rotationSpeed
            let currentRotation = realityEntity.transform.rotation
            let additionalRotation = simd_quatf(angle: rotationAmount, axis: [0, 1, 0])
            realityEntity.transform.rotation = currentRotation * additionalRotation
            
            // Apply pulse scaling
            realityEntity.transform.scale = SIMD3<Float>(pulseScale, pulseScale, pulseScale)
            
            // Update component
            componentManager.addComponent(collectible, to: entityId)
        }
    }
    
    private func updatePlayerEffects() {
        guard let playerId = playerEntityId,
              var playerStatus = componentManager.getComponent(PlayerStatusComponent.self, for: playerId) else { return }
        
        playerStatus.updateEffects()
        componentManager.addComponent(playerStatus, to: playerId)
    }

    // NEW: Metode untuk memperbarui efek kucing
    private func updateCatEffects() {
        guard let catId = catEntityId,
              var catStatus = componentManager.getComponent(CatStatusComponent.self, for: catId) else { return }
        
        catStatus.updateEffects()
        componentManager.addComponent(catStatus, to: catId)
    }
    
    // MARK: - Collision Detection
    
    private func checkCollisions() {
        let ballEntities = componentManager.getAllEntitiesWithComponent(GameEntityComponent.self)
            .filter { entityId in
                guard let gameEntity = componentManager.getComponent(GameEntityComponent.self, for: entityId) else { return false }
                return gameEntity.entityType == .ball
            }
        
        let collectibleEntities = componentManager.getAllEntitiesWithComponent(CollectibleComponent.self)
            .filter { entityId in
                guard let collectible = componentManager.getComponent(CollectibleComponent.self, for: entityId) else { return false }
                return !collectible.isCollected
            }
        
        for ballId in ballEntities {
            for collectibleId in collectibleEntities {
                if checkCollision(ballId: ballId, collectibleId: collectibleId) {
                    collectItem(ballId: ballId, collectibleId: collectibleId)
                }
            }
        }
    }
    
    private func checkCollision(ballId: UUID, collectibleId: UUID) -> Bool {
        guard let ballTransform = componentManager.getComponent(TransformComponent.self, for: ballId),
              let collectibleTransform = componentManager.getComponent(TransformComponent.self, for: collectibleId) else { return false }
        
        let distance = simd_distance(ballTransform.position, collectibleTransform.position)
        return distance < 0.5 // Collision threshold
    }
    
    // MARK: - Item Collection
    
    private func collectItem(ballId: UUID, collectibleId: UUID) {
        guard var collectible = componentManager.getComponent(CollectibleComponent.self, for: collectibleId),
              let realityEntity = realityEntities[collectibleId] else { return }
        
        // Get or create player status component
        var playerStatus: PlayerStatusComponent
        if let existingStatus = componentManager.getComponent(PlayerStatusComponent.self, for: ballId) {
            playerStatus = existingStatus
        } else {
            playerStatus = PlayerStatusComponent(entityId: ballId)
        }
        
        // Mark as collected
        collectible.isCollected = true
        componentManager.addComponent(collectible, to: collectibleId)
        
        // === Logika penerapan efek di sini (di dalam System, bukan Component) ===
        let now = Date()
        switch collectible.collectibleType {
        case .coin:
            playerStatus.totalCollectibles += 1
            gameService?.addPoints(collectible.collectibleType.points) // Menambah skor
            print("✨ Collected \(collectible.collectibleType): +\(collectible.collectibleType.points) points")
        case .shield:
            playerStatus.hasShield = true
            playerStatus.shieldEndTime = now.addingTimeInterval(collectible.collectibleType.effectDuration)
            print("🛡️ Shield collected! Player has shield for \(collectible.collectibleType.effectDuration) seconds!")
        case .fish:
            // Temukan entitas kucing dan terapkan efek kepadanya
            if let catId = self.catEntityId, // Menggunakan properti catEntityId dari CollectibleSystem
               var catStatus = componentManager.getComponent(CatStatusComponent.self, for: catId) { // Menggunakan CatStatusComponent
                
                catStatus.isSpeedBoosted = true
                catStatus.speedMultiplier = 1.5 // Contoh: Kucing 1.5x lebih cepat
                catStatus.speedBoostEndTime = now.addingTimeInterval(collectible.collectibleType.effectDuration)
                
                componentManager.addComponent(catStatus, to: catId)
                print("🐟 Fish collected! Cat is now faster for \(collectible.collectibleType.effectDuration) seconds!")
            } else {
                print("⚠️ Fish collected, but cat entity or CatStatusComponent not found for effect.")
            }
        case .pillow: // NEW: Tambahkan case untuk pillow
                    if let catId = self.catEntityId,
                       var catStatus = componentManager.getComponent(CatStatusComponent.self, for: catId) {
                        
                        catStatus.isStunned = true // Set status stunned menjadi true
                        catStatus.stunEndTime = now.addingTimeInterval(collectible.collectibleType.effectDuration) // Atur timer stun
                        
                        componentManager.addComponent(catStatus, to: catId)
                        print("😴 Pillow collected! Cat is stunned for \(collectible.collectibleType.effectDuration) seconds!")
                    } else {
                        print("⚠️ Pillow collected, but cat entity or CatStatusComponent not found for effect.")
                    }
        case .bubbleGum: // NEW: Tambahkan case untuk bubble gum
                   playerStatus.isSlowMotion = true
                   playerStatus.slowMotionEndTime = now.addingTimeInterval(collectible.collectibleType.effectDuration)
                   print("🐌 Bubble Gum collected! Player is slowed for \(collectible.collectibleType.effectDuration) seconds!")
        }
        
        // Simpan kembali PlayerStatusComponent setelah dimodifikasi
        componentManager.addComponent(playerStatus, to: ballId)
        
        // Play collection effect
        playCollectionEffect(for: collectible.collectibleType, at: realityEntity.position)
        
        // Hide the collectible
        realityEntity.isEnabled = false
    }
    
    private func playCollectionEffect(for type: CollectibleType, at position: SIMD3<Float>) {
        // Create a simple particle effect or visual feedback
        // This is a placeholder for more complex particle systems
        print("✨ Collection effect for \(type) at \(position)")
    }
    
    // MARK: - Public Methods
    
    func registerEntity(_ entity: Entity, with entityId: UUID) {
        realityEntities[entityId] = entity
    }
    
    func setGameService(_ service: GameService) {
        gameService = service
    }
    
    // NEW: Metode untuk menyuntikkan ID entitas kucing dan pemain
    func setCatEntityId(_ id: UUID) {
        self.catEntityId = id
    }

    func setPlayerEntityId(_ id: UUID) {
        self.playerEntityId = id
    }
    
    func setRequiredKeys(_ count: Int) {
        requiredKeysForExit = count
    }
    
    func getPlayerStatus(for playerId: UUID) -> PlayerStatusComponent? {
        return componentManager.getComponent(PlayerStatusComponent.self, for: playerId)
    }

    // NEW: Metode untuk mendapatkan status kucing
    func getCatStatus(for catId: UUID) -> CatStatusComponent? {
        return componentManager.getComponent(CatStatusComponent.self, for: catId)
    }
    
    func canPlayerExit(playerId: UUID) -> Bool {
        guard let playerStatus = getPlayerStatus(for: playerId) else { return true }
        return playerStatus.collectedKeys >= requiredKeysForExit
    }
    
    func getCollectionProgress(for playerId: UUID) -> CollectionProgress {
        guard let playerStatus = getPlayerStatus(for: playerId) else {
            return CollectionProgress(totalItems: 0, collectedItems: 0, keys: 0, requiredKeys: requiredKeysForExit)
        }
        
        let totalCollectibles = componentManager.getAllEntitiesWithComponent(CollectibleComponent.self).count
        let collectedCount = componentManager.getAllEntitiesWithComponent(CollectibleComponent.self)
            .compactMap { componentManager.getComponent(CollectibleComponent.self, for: $0) }
            .filter { $0.isCollected }
            .count
        
        return CollectionProgress(
            totalItems: totalCollectibles,
            collectedItems: collectedCount,
            keys: playerStatus.collectedKeys,
            requiredKeys: requiredKeysForExit
        )
    }
    
    // MARK: - Debug Methods
    
    func getCollectibleDebugInfo() -> String {
        let collectibleEntities = componentManager.getAllEntitiesWithComponent(CollectibleComponent.self)
        let collected = collectibleEntities.compactMap { componentManager.getComponent(CollectibleComponent.self, for: $0) }
            .filter { $0.isCollected }.count
        
        var info = "=== Collectible System Debug ===\n"
        info += "Total Collectibles: \(collectibleEntities.count)\n"
        info += "Collected: \(collected)\n"
        info += "Required Keys: \(requiredKeysForExit)\n"
        
        // Debug info untuk player status
        if let playerId = playerEntityId, let playerStatus = getPlayerStatus(for: playerId) {
            info += "Player Effects: \(playerStatus.activeEffectsDescription)\n"
        }

        // Debug info untuk cat status
        if let catId = catEntityId, let catStatus = getCatStatus(for: catId) {
            info += "Cat Speed Boosted: \(catStatus.isSpeedBoosted) (Multiplier: \(catStatus.speedMultiplier))\n"
            info += "Cat Is Stunned: \(catStatus.isStunned)\n"
        }
        
        
        
        return info
    }
}

// MARK: - Collection Progress

struct CollectionProgress {
    let totalItems: Int
    let collectedItems: Int
    let keys: Int
    let requiredKeys: Int
    
    var completionPercentage: Float {
        guard totalItems > 0 else { return 0 }
        return Float(collectedItems) / Float(totalItems)
    }
    
    var canExit: Bool {
        return keys >= requiredKeys
    }
    
    var description: String {
        return "Collected: \(collectedItems)/\(totalItems) | Keys: \(keys)/\(requiredKeys)"
    }
}

// MARK: - Entity Factory Extension

extension EntityFactory {
    
    /// Create a collectible item entity with ECS components
    func createCollectible(
        type: CollectibleType,
        at position: SIMD3<Float>,
        componentManager: ComponentManager
    ) -> (Entity, UUID) {
        let collectible = Entity()
        let entityId = UUID()
        collectible.name = "Collectible_\(type)_\(entityId)"
        
        // Create visual representation based on type
        let geometry: MeshResource
        let size: Float = 0.3
        
        switch type {
        case .coin:
            geometry = MeshResource.generateSphere(radius: size * 0.5)
        case .shield:
            geometry = MeshResource.generateSphere(radius: size * 0.6)
        case .fish:
            geometry = MeshResource.generateSphere(radius: size * 0.3)
        case .pillow:
            geometry = MeshResource.generateBox(size: SIMD3<Float>(size * 0.8, size * 0.4, size * 0.6))
        case .bubbleGum:
            geometry = MeshResource.generateSphere(radius: size * 0.4)

        }
        
        let material = SimpleMaterial(color: type.color, isMetallic: false)
        collectible.components.set(ModelComponent(mesh: geometry, materials: [material]))
        
        // Set position
        collectible.position = position
        
        // Add ECS components
        let transformComponent = TransformComponent(
            entityId: entityId,
            position: position,
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: SIMD3<Float>(1, 1, 1)
        )
        componentManager.addComponent(transformComponent, to: entityId)
        
        let collectibleComponent = CollectibleComponent(entityId: entityId, type: type)
        componentManager.addComponent(collectibleComponent, to: entityId)
        
        let gameEntityComponent = GameEntityComponent(
            entityId: entityId,
            entityType: .collectible,
            isActive: true,
            isCollectable: true
        )
        componentManager.addComponent(gameEntityComponent, to: entityId)
        
        // Add collision detection
        let collision = CollisionComponent(shapes: [.generateSphere(radius: size)])
        collectible.components.set(collision)
        
        print("✨ Created \(type) collectible at \(position)")
        return (collectible, entityId)
    }
    
    /// Create multiple collectibles distributed throughout the maze
    func createMazeCollectibles(
        mazeService: MazeService,
        componentManager: ComponentManager
    ) -> [(Entity, UUID)] {
        var collectibles: [(Entity, UUID)] = []
        let maze = mazeService.maze
        
        // Calculate number of collectibles based on maze size
        let mazeArea = maze.configuration.width * maze.configuration.height
        let baseCollectibles = max(3, mazeArea / 8) // At least 3, or 1 per 8 cells
        
        var collectibleCounts: [CollectibleType: Int] = [:]
        
//        // Distribute collectibles by rarity
        for type in CollectibleType.allCases {
            let count = Int(Float(baseCollectibles) * type.rarity)
            collectibleCounts[type] = max(1, count) // Pastikan minimal 1 untuk semua tipe
        }
        
        // Place collectibles in random empty cells
        var usedPositions: Set<SIMD2<Int>> = []
        usedPositions.insert(maze.startPosition) // Don't place at start
        usedPositions.insert(maze.exitPosition)  // Don't place at exit
        
        for (type, count) in collectibleCounts {
            for _ in 0..<count {
                if let position = findRandomEmptyPosition(in: maze, excluding: usedPositions) {
                    usedPositions.insert(position)
                    let worldPosition = mazeService.getWorldPosition(for: position).offsetY(0.5)
                    let (entity, id) = createCollectible(type: type, at: worldPosition, componentManager: componentManager)
                    collectibles.append((entity, id))
                }
            }
        }
        
        print("✨ Created \(collectibles.count) collectibles in maze")
        return collectibles
    }
    
    private func findRandomEmptyPosition(in maze: MazeData, excluding used: Set<SIMD2<Int>>) -> SIMD2<Int>? {
        var attempts = 0
        let maxAttempts = 100
        
        while attempts < maxAttempts {
            let x = Int.random(in: 0..<maze.configuration.width)
            let y = Int.random(in: 0..<maze.configuration.height)
            let position = SIMD2<Int>(x, y)
            
            if !used.contains(position) {
                return position
            }
            
            attempts += 1
        }
        
        return nil // Couldn't find empty position
    }
}
