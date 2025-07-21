//
//  GameView.swift
//  MazeHamster
//
//  Created by Ali zaenal on 21/07/25.
//

import SwiftUI
import RealityKit


struct GameView: View {
    @EnvironmentObject var gameViewModel: GameViewModel
    
    var body: some View {
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
}

#Preview {
    @Previewable @StateObject var gameViewModel = GameViewModel()
    GameView()
        .environmentObject(gameViewModel)
}
