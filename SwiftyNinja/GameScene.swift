//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Noah Patterson on 12/21/16.
//  Copyright © 2016 noahpatterson. All rights reserved.
//

import SpriteKit
import GameplayKit
import AVFoundation

class GameScene: SKScene {
    var gameScore: SKLabelNode!
    var bombSoundEffect: AVAudioPlayer!
    var score: Int = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    var activeSliceForeGround: SKShapeNode!
    var activeSliceBackGround: SKShapeNode!
    
    var activeSlices = [CGPoint]()
    var activeEnemies = [SKSpriteNode]()
    
    var isSwooshSoundActive = false
    
    enum ForceBomb {
        case never, always, random
    }
    
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed   = 0.85
        
        createScore()
        createLives()
        createSlices()
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        //remove any slices
        activeSlices.removeAll(keepingCapacity: true)
        
        if let touch = touches.first {
            
            // add slice to active slices
            let location = touch.location(in: self)
            activeSlices.append(location)
            
            redrawActiveSlice()
            
            //remove actions on active slices -- they could be in a fadeOut action
            activeSliceBackGround.removeAllActions()
            activeSliceForeGround.removeAllActions()
            
            activeSliceBackGround.alpha = 1
            activeSliceForeGround.alpha = 1
        }
        
       
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        activeSlices.append(location)
        redrawActiveSlice()
        
        if !isSwooshSoundActive {
            playSwooshSound()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBackGround.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceForeGround.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        
        //count bombs, stop sound if there are zero bombs
        var bombCount = 0
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
        }
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .left
        gameScore.position = CGPoint(x: 8, y: 8)
        gameScore.fontSize = 48
        
        addChild(gameScore)
    }
    
    func createLives() {
        for i in 0..<3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i*70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        activeSliceBackGround = SKShapeNode()
        activeSliceBackGround.zPosition = 2
        
        activeSliceForeGround = SKShapeNode()
        activeSliceForeGround.zPosition = 2
        
        activeSliceBackGround.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBackGround.lineWidth = 9
        
        activeSliceForeGround.strokeColor = .white
        activeSliceForeGround.lineWidth = 5
        
        addChild(activeSliceBackGround)
        addChild(activeSliceForeGround)
    }
    
    func redrawActiveSlice() {
        
        //we don't have enough points to draw a path so clear shapes and exit
        if activeSlices.count < 2 {
            activeSliceBackGround.path = nil
            activeSliceForeGround.path = nil
            return
        }
        
        //prevent swipes from growing too long by removing some
        while activeSlices.count > 12 {
            activeSlices.remove(at: 0)
        }
        
        //start line at first swipe then draw line as we go
        let path = UIBezierPath()
        path.move(to: activeSlices.first!)
        
        for i in 1..<activeSlices.count {
            path.addLine(to: activeSlices[i])
        }
        
        //update slice shape path with their designs
        activeSliceBackGround.path = path.cgPath
        activeSliceForeGround.path = path.cgPath
    }
    
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNum = RandomInt(min: 1, max: 3)
        let soundName = "swoosh\(randomNum).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        run(swooshSound) {
            [unowned self] in
            self.isSwooshSoundActive = false
        }
    }
    
    func createEnemy(forceBomb: ForceBomb = .random) {
        var enemy: SKSpriteNode
        var enemyType = RandomInt(min: 0, max: 6)
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            //bomb code goes here
            //create a new node to hold both the bomb and the fuse
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            //create the bomb image
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            //if bomb sound effect is playing, stop and destroy it
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
            
            //create a new bomb sound effect then play it
            let path = Bundle.main.path(forResource: "sliceBombFuse.caf", ofType: nil)!
            let url = URL(fileURLWithPath: path)
            let sound = try! AVAudioPlayer(contentsOf: url)
            bombSoundEffect = sound
            sound.play()
            
            //create particle emmitter for bomb fuse
            let emitter = SKEmitterNode(fileNamed: "sliceFuse")!
            emitter.position = CGPoint(x: 76, y: 64)
            enemy.addChild(emitter)
            
        } else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        //position code goes here
        //give enemy a random position off the bottom of the screen
        let randomPosition = CGPoint(x: RandomInt(min: 64 ,max: 960), y: -128)
        enemy.position = randomPosition
        
        //random spin speed
        let randomAngularVelocity = CGFloat(RandomInt(min: -6, max: 6))/2.0
        
        //random horizontal travel based on position
        var randomXVelocity = 0
        if randomPosition.x < 256 {
            randomXVelocity = RandomInt(min: 8, max: 15)
        } else if randomPosition.x < 512 {
            randomXVelocity = RandomInt(min: 3, max: 5)
        } else if randomPosition.x < 768 {
            randomXVelocity = -RandomInt(min: 3, max: 5)
        } else {
            randomXVelocity = -RandomInt(min: 8, max: 15)
        }
        
        //random fly speed
        let randomYVelocity = RandomInt(min: 24, max: 32)
        
        //give all enemies a circular physics body so they don't collide
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody!.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody!.angularVelocity = randomAngularVelocity
        enemy.physicsBody!.collisionBitMask = 0
        
        addChild(enemy)
        activeEnemies.append(enemy)
    }
}






