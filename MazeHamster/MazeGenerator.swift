//
//  MazeGenerator.swift
//  DraftBallMazeGame
//
//  Created by Rafi Abhista  on 10/07/25.
//

import Foundation

enum Wall {
    case top, right, bottom, left
}

struct MazeCell {
    var x: Int
    var y: Int
    var walls: Set<Wall> = [.top, .right, .bottom, .left]
    var visited = false
}

class MazeGenerator {
    var width: Int
    var height: Int
    var grid: [[MazeCell]]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.grid = (0..<width).map { x in
            (0..<height).map { y in
                MazeCell(x: x, y: y)
            }
        }
        generateMaze()
    }

    func generateMaze() {
        dfs(x: 0, y: 0)
    }

    func dfs(x: Int, y: Int) {
        grid[x][y].visited = true

        let directions: [(Int, Int, Wall, Wall)] = [
            (0, -1, .top, .bottom),
            (1, 0, .right, .left),
            (0, 1, .bottom, .top),
            (-1, 0, .left, .right)
        ].shuffled()

        for (dx, dy, wall, oppWall) in directions {
            let nx = x + dx, ny = y + dy
            if nx >= 0, ny >= 0, nx < width, ny < height, !grid[nx][ny].visited {
                grid[x][y].walls.remove(wall)
                grid[nx][ny].walls.remove(oppWall)
                dfs(x: nx, y: ny)
            }
        }
    }
}
