//
//  ContentView.swift
//  MazeBall
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
            if gameViewModel.gameState == .menu {
                menuView
            } else if gameViewModel.gameState == .completed {
                gameCompletedView
            } else if gameViewModel.gameState == .failed {
                gameOverView
            } else {
                gameView
            }
            
            // UI Overlay (only show during gameplay)
            if gameViewModel.gameState == .playing || gameViewModel.gameState == .paused {
                gameOverlay
            }
        }
        .background(Color.black)
        .onAppear {
            gameViewModel.viewDidAppear()
        }
        .onDisappear {
            gameViewModel.viewWillDisappear()
        }

    }
    
    // MARK: - Menu View
    
    private var menuView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Game Title
            VStack(spacing: 10) {
                Text("MazeBall")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Tilt to Navigate")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Instructions
            VStack(spacing: 15) {
                Text("🎯 Guide the ball to the exit")
                Text("🐱 Avoid the cat")
                Text("📱 Tilt your device to move")
                Text("🏃‍♂️ Cat spawns after 2 seconds")
            }
            .font(.body)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            
            Spacer()
            
            // Start Button
            Button("Start Game") {
                HapticManager.impact(.medium)
                gameViewModel.startGame()
            }
            .buttonStyle(GameButtonStyle(color: .green))
            .scaleEffect(1.2)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Game Completed View
    
    private var gameCompletedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success Animation
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 80))
                    .scaleEffect(gameViewModel.isGameCompleted ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: gameViewModel.isGameCompleted)
                
                Text("Congratulations!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("You Escaped the Maze!")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Score Display
            VStack(spacing: 10) {
                Text("Final Score")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("\(gameViewModel.score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                
                Text("Maze Size: \(gameViewModel.currentMazeSize.x)×\(gameViewModel.currentMazeSize.y)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 15) {
                Button("Play Again") {
                    HapticManager.success()
                    gameViewModel.resetGame()
                }
                .buttonStyle(GameButtonStyle(color: .green))
                
                Button("New Maze") {
                    HapticManager.impact(.medium)
                    gameViewModel.generateNewMaze()
                }
                .buttonStyle(GameButtonStyle(color: .blue))
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            HapticManager.success()
        }
    }
    
    // MARK: - Game Over View
    
    private var gameOverView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Game Over Animation
            VStack(spacing: 20) {
                Text("😿")
                    .font(.system(size: 80))
                    .scaleEffect(gameViewModel.isGameFailed ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: gameViewModel.isGameFailed)
                
                Text("Game Over")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Text("The Cat Caught You!")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Score Display
            VStack(spacing: 10) {
                Text("Score")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("\(gameViewModel.score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                Text("Maze Size: \(gameViewModel.currentMazeSize.x)×\(gameViewModel.currentMazeSize.y)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            
            Spacer()
            
            // Motivational Message
            VStack(spacing: 10) {
                Text("Don't Give Up!")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Try different strategies:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("• Move quickly when cat spawns")
                    Text("• Use maze walls to block the cat")
                    Text("• Plan your route to the exit")
                }
                .font(.caption)
                .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 15) {
                Button("Try Again") {
                    HapticManager.impact(.heavy)
                    gameViewModel.resetGame()
                }
                .buttonStyle(GameButtonStyle(color: .orange))
                
                Button("New Maze") {
                    HapticManager.impact(.medium)
                    gameViewModel.generateNewMaze()
                }
                .buttonStyle(GameButtonStyle(color: .purple))
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.red.opacity(0.3), .orange.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            HapticManager.error()
        }
    }
    
    // MARK: - Game View
    
    private var gameView: some View {
        RealityView { content in
            // Initialize the game scene through ViewModel
            let scene = gameViewModel.initializeScene()
            content.add(scene)
        } update: { content in
            // Update the game on each frame
            gameViewModel.updateGame(deltaTime: 1.0/60.0)
        }
        .realityViewCameraControls(.none)
        .disabled(gameViewModel.isLoading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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
            
            // Cat Status
            VStack(alignment: .center) {
                Text("Cat Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(gameViewModel.catStatusDescription)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(gameViewModel.showCatCountdown ? .orange : .red)
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
            
            // Cat Countdown
            if gameViewModel.showCatCountdown {
                Text(gameViewModel.catCountdownText)
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
                    .animation(.easeInOut, value: gameViewModel.catSpawnCountdown)
            }
            
            // Game Control Buttons
            HStack(spacing: 20) {
                // Pause Button
                if gameViewModel.canPauseGame {
                    Button("Pause") {
                        HapticManager.impact(.light)
                        gameViewModel.pauseGame()
                    }
                    .buttonStyle(GameButtonStyle(color: .orange))
                }
                
                // Resume Button
                if gameViewModel.canResumeGame {
                    Button("Resume") {
                        HapticManager.impact(.light)
                        gameViewModel.resumeGame()
                    }
                    .buttonStyle(GameButtonStyle(color: .blue))
                }
                
                // Reset Button
                Button("Reset") {
                    HapticManager.impact(.medium)
                    gameViewModel.resetGame()
                }
                .buttonStyle(GameButtonStyle(color: .red))
            }
            
            // New Maze Button
            Button("New Maze") {
                HapticManager.impact(.medium)
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

// MARK: - Haptic Feedback Manager

class HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    static func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
}

#Preview {
    ContentView()
}
