//
//  ContentView.swift
//  experiment1-mazeball
//
//  Created by Ali zaenal on 10/07/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var gameViewModel = GameViewModel()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Main Game View
            gameView
            
            // UI Overlay
            gameOverlay
        }
        .background(Color.black)  // Add dark background for better contrast
        .onAppear {
            gameViewModel.viewDidAppear()
        }
        .onDisappear {
            gameViewModel.viewWillDisappear()
        }
    }
    
    // MARK: - View Components
    
    private var gameView: some View {
        RealityView { content in
            // Initialize the game scene through ViewModel
            let scene = gameViewModel.initializeScene()
            content.add(scene)
        } update: { content in
            // Update the game on each frame
            gameViewModel.updateGame(deltaTime: 1.0/60.0)
        }
        .realityViewCameraControls(.none)  // Disable camera controls to prevent interference
        .disabled(gameViewModel.isLoading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Ensure full screen coverage
        .clipped()  // Clip to bounds for proper centering
    }
    
    private var gameOverlay: some View {
        VStack {
            // Top HUD
            topHUD
            
            Spacer()
            
            // Game Controls
            gameControls
        }
        .padding()
    }
    
    private var topHUD: some View {
        HStack {
            // Score Display
            VStack(alignment: .leading) {
                Text("Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(gameViewModel.score)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            // Game State Display
            VStack(alignment: .trailing) {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(gameStateText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(gameStateColor)
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var gameControls: some View {
        VStack(spacing: 20) {
            // Loading Indicator
            if gameViewModel.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            // Error Message
            if let errorMessage = gameViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
            }
            
            // Game Control Buttons
            HStack(spacing: 20) {
                // Start/Resume Button
                if gameViewModel.canStartGame {
                    Button("Start Game") {
                        gameViewModel.startGame()
                    }
                    .buttonStyle(GameButtonStyle(color: .green))
                } else if gameViewModel.canResumeGame {
                    Button("Resume") {
                        gameViewModel.resumeGame()
                    }
                    .buttonStyle(GameButtonStyle(color: .blue))
                }
                
                // Pause Button
                if gameViewModel.canPauseGame {
                    Button("Pause") {
                        gameViewModel.pauseGame()
                    }
                    .buttonStyle(GameButtonStyle(color: .orange))
                }
                
                // Reset Button
                if gameViewModel.gameState != .menu {
                    Button("Reset") {
                        gameViewModel.resetGame()
                    }
                    .buttonStyle(GameButtonStyle(color: .red))
                }
            }
            
            // New Maze Button
            Button("New Maze") {
                gameViewModel.generateNewMaze()
            }
            .buttonStyle(GameButtonStyle(color: .purple))
            .disabled(gameViewModel.isGameActive)
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Computed Properties
    
    private var gameStateText: String {
        switch gameViewModel.gameState {
        case .menu:
            return "Menu"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed!"
        case .failed:
            return "Failed"
        }
    }
    
    private var gameStateColor: Color {
        switch gameViewModel.gameState {
        case .menu:
            return .primary
        case .playing:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .blue
        case .failed:
            return .red
        }
    }
}

// MARK: - Custom Button Style

struct GameButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .semibold))
            .frame(minWidth: 80, minHeight: 44)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
    


#Preview {
    ContentView()
}

// MARK: - Architecture Notes

/*
 🏗️ ARCHITECTURE REFACTORING COMPLETE! 🏗️
 
 This ContentView has been successfully refactored from a monolithic 440-line file to a clean, 
 maintainable MVVM + ECS architecture:

 ✅ OLD (Bad):
 - 440 lines of mixed responsibilities
 - Direct physics, input, and game logic in View
 - Hardcoded values and tight coupling
 - No separation of concerns
 - Difficult to test and maintain

 ✅ NEW (Good):
 - Clean 150-line View focused only on UI
 - Proper MVVM architecture with GameViewModel
 - ECS (Entity Component System) for game entities
 - Service layer for modular functionality
 - Proper separation of concerns
 - Easy to test, maintain, and extend
 - Team-friendly with clear boundaries

 📦 Architecture Components:
 - Model: GameModels.swift (data structures)
 - View: ContentView.swift (UI only)
 - ViewModel: GameViewModel.swift (coordination)
 - Services: InputService, PhysicsService, MazeService, GameService, CameraService
 - ECS: Components.swift, Systems.swift (entity management)
 - Factory: EntityFactory.swift (entity creation)

 🎯 Benefits:
 - Maintainable and scalable
 - Easy to divide work between team members
 - Testable components
 - Clear separation of responsibilities
 - Modern Swift/SwiftUI patterns
 - Production-ready architecture
 */
