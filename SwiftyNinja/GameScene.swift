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
    var gameEnded = false
    var gameScore: SKLabelNode!
    let gameOverLabel = SKLabelNode(fontNamed: "Chalkduster")
    let playAgainLabel = SKLabelNode(fontNamed: "Chalkduster")
    var highScoreLabel = SKNode()
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
    
    enum SequenceType: Int {
        case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
    }
    
    enum ForceBomb {
        case never, always, random
    }
    
    //top scores
    var highScores: [[String:Int]]! {
        didSet {
            if let scores = highScores {
                if scores.count >= 2 {
                    highScores = scores.sorted { first,second  in
                        return first.first!.value > second.first!.value
                    }
                }
            }
        }
    }
    
    //showing enemies
    var popupTime = 0.9
    var sequence: [SequenceType]!
    var sequencePosition = 0 //where we are in the game
    var chainDelay = 3.0 //how long to delay after creating a .chain or .fastChain
    var nextSequenceQueued = true //know when all enemies are destroyed and we need to create more
    
    override func didMove(to view: SKView) {
        highScores = [[String:Int]]()
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
        getTopScores()
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0 ... 1000 {
            let nextSequence = SequenceType(rawValue: RandomInt(min: 2, max: 7))!
            sequence.append(nextSequence)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            [unowned self] in
            self.tossEnemies()
        }
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
            
            let nodesAtPoint = nodes(at: location)
            
            for node in nodesAtPoint {
                if node.name == "playAgain" {
                    playAgain()
                }
            }
        }
        
       
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameEnded { return }
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        activeSlices.append(location)
        redrawActiveSlice()
        
        if !isSwooshSoundActive {
            playSwooshSound()
        }
        
        let nodesAtPoint = nodes(at: location)
        
        for node in nodesAtPoint {
            if node.name == "enemy" {
                //create particle effect over penguin
                let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy")!
                emitter.position = node.position
                addChild(emitter)
                
                //clear node name so it can't be swiped again
                node.name = ""
                
                //disable physics so it doesn't continue to fall
                node.physicsBody!.isDynamic = false
                
                //scale and fade out
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut  = SKAction.fadeOut(withDuration: 0.2)
                let group    = SKAction.group([scaleOut, fadeOut])
                
                //remove from scene
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                node.run(seq)
                
                //add one to the player's score
                score += 1
                
                //remove enemy from active
                let enemyIndex = activeEnemies.index(of: node as! SKSpriteNode)!
                activeEnemies.remove(at: enemyIndex)
                
                //play a hit sound
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
            } else if node.name == "bomb" {
                let nodeParent = node.parent!
                let emitter = SKEmitterNode(fileNamed: "sliceHitBomb")!
                emitter.position = nodeParent.position
                addChild(emitter)
                
                node.name = ""
                nodeParent.physicsBody!.isDynamic = false
                
                //scale and fade out
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut  = SKAction.fadeOut(withDuration: 0.2)
                let group    = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                nodeParent.run(seq)
                
                let enemyIndex = activeEnemies.index(of: nodeParent as! SKSpriteNode)!
                activeEnemies.remove(at: enemyIndex)
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                endGame(triggeredByBomb: true)
            }
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
        
        if activeEnemies.count > 0 {
            for node in activeEnemies {
                if node.position.y < -140 {
//                    node.removeFromParent()
//                    
//                    if let index = activeEnemies.index(of: node) {
//                        activeEnemies.remove(at: index)
//                    }
                    node.removeAllActions()
                    
                    if node.name == "enemy" {
                        node.name = ""
                        subtractLife()
                        
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    }
                }
            }
        } else {
            if !nextSequenceQueued {
                if  sequencePosition > sequence.count {
                    endGame()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [unowned self] in
                    self.tossEnemies()
                }
                self.nextSequenceQueued = true
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
    
    func tossEnemies() {
        if gameEnded { return }
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
        case .one:
            createEnemy()
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
        case .two:
            createEnemy()
            createEnemy()
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
        case .chain:
            createEnemyChain(speedMultiplier: 2.0)
        case .fastChain:
            createEnemyChain(speedMultiplier: 10.0)
        }
        
        sequencePosition += 1
        nextSequenceQueued = false
    }
    
    func createEnemyChain(speedMultiplier: Double) {
        createEnemy()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / speedMultiplier)) {
            //execute
            [unowned self] in
            self.createEnemy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / speedMultiplier * 2)) {
            //execute
            [unowned self] in
            self.createEnemy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / speedMultiplier) * 3) {
            //execute
            [unowned self] in
            self.createEnemy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / speedMultiplier) * 4) {
            //execute
            [unowned self] in
            self.createEnemy()
        }
    }
    
    func endGame(triggeredByBomb: Bool = false) {
        if gameEnded {
            return
        }
        
        gameEnded = true
        physicsWorld.speed = 0
//        isUserInteractionEnabled = false
        
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
    
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
        
        gameOverLabel.text = "Game Over!"
        gameOverLabel.position = CGPoint(x: 512, y: 700) //center
        gameOverLabel.zPosition = 2
        addChild(gameOverLabel)
        
        playAgainLabel.text = "Play Again?"
        playAgainLabel.position = CGPoint(x: 512, y: 650)
        playAgainLabel.name = "playAgain"
        playAgainLabel.zPosition = 2
        addChild(playAgainLabel)
        
        //add high score if in top 5

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            [unowned self] in
            if self.highScores.count >= 5 && self.score > self.highScores[4].first!.value {
                self.askForHighScoreName()
            } else if self.highScores.count < 5 {
                self.askForHighScoreName()
            } else {
                self.showHighScores()
            }
        }
    }
    
    func askForHighScoreName() {
        let vc = UIAlertController(title: "High Score!", message: "Set your high score", preferredStyle: .alert)
        vc.addTextField {
            textField in
            textField.placeholder = "Name"
        }
        vc.addAction(UIAlertAction(title: "Ok", style: .default) {
            [unowned self, vc] action in
            let name = vc.textFields!.first!.text ?? "Unknown"
            self.setTopScore(name: name == "" ? "Unknown" : name, score: self.score)
            self.showHighScores()
        })
        view!.window!.rootViewController!.present(vc, animated: true)
    }
    
    func showHighScores() {
        var highScoreString = ""
        for score in highScores {
            highScoreString += "\(score.first!.key): \(score.first!.value)\n"
        }
        displayMultiLineTextAt(x: 512, y: 600, text: "High Scores\n" + highScoreString)
    }
    
    func displayMultiLineTextAt(x: CGFloat, y: CGFloat, text: String, align: SKLabelHorizontalAlignmentMode = .center, lineHeight: CGFloat = 40.0) {
        highScoreLabel.position = CGPoint(x: x, y: y)
        highScoreLabel.zPosition = 2
        var lineAt: CGFloat = 0
        for line in text.components(separatedBy: "\n") {
            let labelNode = SKLabelNode(fontNamed: "Chalkduster")
            labelNode.horizontalAlignmentMode = align
            labelNode.position = CGPoint(x: 0, y: lineAt)
            labelNode.text = line
            highScoreLabel.addChild(labelNode)
            lineAt -= lineHeight
        }
        addChild(highScoreLabel)
    }
    
    func subtractLife() {
        lives -= 1
        
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame()
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        
        life.xScale = 1.3
        life.yScale = 1.3
        
        run(SKAction.scale(to: 1, duration: 0.1))
    }
    
    func playAgain() {
        gameEnded = false
        sequencePosition = 0
        score = 0
        lives = 3
        popupTime = 0.9
        chainDelay = 3.0
        
        for life in livesImages {
            life.texture = SKTexture(imageNamed: "sliceLife")
            life.xScale = 1
            life.yScale = 1
        }
        
        for enemy in activeEnemies {
            enemy.removeFromParent()
        }
        activeEnemies.removeAll(keepingCapacity: true)
        physicsWorld.speed =  0.85
        
        nextSequenceQueued = false
        gameOverLabel.removeFromParent()
        playAgainLabel.removeFromParent()
        highScoreLabel.removeAllChildren()
        highScoreLabel.removeFromParent()
    }
    
    func getTopScores() {
        let defaults = UserDefaults.standard
        
        let currentHighScores = defaults.object(forKey: "highScores") as? [[String:Int]] ?? [[String:Int]]()
        highScores = currentHighScores
        if highScores.count >= 2 {
            highScores.sort { first,second  in
                return first.first!.value > second.first!.value
            }
        }
    }
    
    func setTopScore(name: String, score: Int) {
        let defaults = UserDefaults.standard
        
//        var currentHighScores = defaults.object(forKey: "highScores") as? [String:Int] ?? [String:Int]()
        let highScore = [name:score]
        if highScores.count >= 5 {
            highScores[4] = highScore
        } else {
            highScores.append(highScore)
        }
        //        highScores = currentHighScores
        defaults.set(highScores, forKey: "highScores")
    }
}






