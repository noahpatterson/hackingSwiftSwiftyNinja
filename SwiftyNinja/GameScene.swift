//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Noah Patterson on 12/21/16.
//  Copyright © 2016 noahpatterson. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    var gameScore: SKLabelNode!
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
    
    var isSwooshSoundActive = false
    
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
}
