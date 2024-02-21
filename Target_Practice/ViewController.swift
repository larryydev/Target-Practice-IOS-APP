//
//  ViewController.swift
//  Target_Practice
//
//  Created by Sam Yao on 12/2/23.
//

import UIKit
import SceneKit
import ARKit
import Vision
import CoreMotion
import SmartHitTest
import FocusNode

extension ARSCNView: ARSmartHitTest {}

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.focusNode.updateFocusNode()
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var freezeFrame: UIButton!
    
    @IBOutlet weak var targetSelector: UIStepper!
    @IBOutlet weak var segmentController: UISegmentedControl!
    @IBOutlet weak var arrowImageView: UIImageView!// TODO:: add in proper arrow implementation
    @IBOutlet weak var fireButton: UIButton!
    
    @IBOutlet weak var scoreLabel: UILabel!
    let audio = AudioModel()

    var motionManager = CMMotionManager()
    var diff : Double = 0
    var isFiring = false
    var scene : SCNScene!
    var cameraNode : SCNNode!
    var planeNode : SCNNode!
    var arrowNode : SCNNode!
    var initialAttitude: (roll: Double, pitch:Double, yaw:Double)?
    let focusNode = FocusSquare()
    var score = 0
    var lastNode:SCNNode? = nil
    var startingPoint: Date?
    var isPressing: Bool = false
    var frictionCoeff: CGFloat = CGFloat(1.0)
    
    @IBOutlet weak var powerBar: UIProgressView!
    var obj_material : Int = 0
    let animation = CATransition()
    let animationKey = convertFromCATransitionType(CATransitionType.push)
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        setupMotionManager()
        
        createArrowNode()
        shootArrow()
        sceneView.frame = self.view.bounds
        self.sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
                
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene.physicsWorld.contactDelegate = self
        startingPoint = Date()
        self.focusNode.viewDelegate = sceneView
        sceneView.scene.rootNode.addChildNode(self.focusNode)
        setupMotion()
    }
    
    // MARK: Motion in World
    func setupMotion(){
        // use motion for camera movement
        motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 1/30.0
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main)
        {
            (deviceMotion, error) -> Void in
            
            if let deviceMotion = deviceMotion{
                if (self.initialAttitude == nil)
                {
                    // save initial orientaton of phone
                    // this is a reference point, we could also set these
                    // manually, assuming a starting phone orientation
                    self.initialAttitude = (deviceMotion.attitude.roll,
                                            deviceMotion.attitude.pitch,
                                            deviceMotion.attitude.yaw)
                }
                
                if let initialAttitude = self.initialAttitude{
                    // update camera angle based upon the difference to original position
                    let pitch = Float(initialAttitude.pitch - deviceMotion.attitude.pitch)
                    let yaw = Float(initialAttitude.yaw - deviceMotion.attitude.yaw)
                    
                    // euler angles define rotation of rigid body
                    // the x,y,z angles correspond to pitch, yaw, and roll, respectively
                    // so this code will adjust the camera view in response to phone position
                    self.cameraNode.eulerAngles.x = -pitch
                    self.cameraNode.eulerAngles.y = -yaw
                }
                
                
                // here we setup the gravity in the world to update with the phone
                self.scene.physicsWorld.gravity.x =  Float(deviceMotion.gravity.x)*9.8
                self.scene.physicsWorld.gravity.y =  Float(deviceMotion.gravity.y)*9.8
                self.scene.physicsWorld.gravity.z = -9.8 // always have gravity down //Float(deviceMotion.gravity.z)*9.8
                
            }
            
        }
    
    }
    
    func shootArrow() {
        // Load the arrow scene
        scene = SCNScene()
        
        scene.physicsWorld.gravity = SCNVector3(x: 0, y: 0, z: 0 )
        // Set the initial position of the arrow node in front of the camera
        // Setup camera position from existing scene
        if let cameraNodeTmp = scene.rootNode.childNode(withName: "camera", recursively: true){
            cameraNode = cameraNodeTmp
            sceneView.scene.rootNode.addChildNode(cameraNode)
            }
                
        if let lighting = scene.rootNode.childNode(withName: "Lighting", recursively: true){
            sceneView.scene.rootNode.addChildNode(lighting)
            }
        
        sceneView.scene
        sceneView.showsStatistics = true

    }
    
    @IBAction func targetSelector(_ sender: UISegmentedControl) {
        
        if sender.selectedSegmentIndex == 0 {
           obj_material = 0
        }
        if sender.selectedSegmentIndex == 1 {
           obj_material = 1
        }
    }
    
    @IBAction func longPressHandler(_ sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began{
            self.isPressing = true
            self.isFiring = true
            print("Ended Began State. State: \(self.isPressing)")
            self.startingPoint = Date()
            Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) { _ in
                if self.isFiring{
                    self.powerBar.progress = Float(self.startingPoint!.timeIntervalSinceNow * -1)/7
                }else{
                    self.powerBar.progress = 0.0
                }
                
            }

        }
        
        if sender.state == .ended{
            audio.startProcesingAudioFileForPlayback()
            audio.togglePlaying()
            self.isPressing = false
            print("Ended End State. State: \(self.isPressing)")

            //draw and release arrow
            isFiring = false
            
            if let arrowNode = createArrowNode() {
                configureArrowNode(arrowNode)
                
                // Add the arrow node to the scene
                sceneView.scene.rootNode.addChildNode(arrowNode)
                
                if let currentFrame = sceneView.session.currentFrame {
                    // Get the camera's position and orientation
                    let translation = matrix_identity_float4x4
                    let arrowTransform = currentFrame.camera.transform * translation
                    
                    // Set the arrow node's transform
                    arrowNode.simdTransform = arrowTransform
                    
                    // Add arrow node to the scene
                    sceneView.scene.rootNode.addChildNode(arrowNode)
                    // use motion for camera movement
                    motionManager = CMMotionManager()
                    motionManager.deviceMotionUpdateInterval = 1/30.0
                    
                    motionManager.startDeviceMotionUpdates(to: OperationQueue.main)
                    {
                        (deviceMotion, error) -> Void in
                        
                        if let deviceMotion = deviceMotion{
                            if (self.initialAttitude == nil)
                            {
                                // save initial orientaton of phone
                                // this is a reference point, we could also set these
                                // manually, assuming a starting phone orientation
                                self.initialAttitude = (deviceMotion.attitude.roll,
                                                        deviceMotion.attitude.pitch,
                                                        deviceMotion.attitude.yaw)
                            }
                            
                            if let initialAttitude = self.initialAttitude{
                                // update camera angle based upon the difference to original position
                                let pitch = Float(initialAttitude.pitch - deviceMotion.attitude.pitch)
                                let yaw = Float(initialAttitude.yaw - deviceMotion.attitude.yaw)
                                
                                // euler angles define rotation of rigid body
                                // the x,y,z angles correspond to pitch, yaw, and roll, respectively
                                // so this code will adjust the camera view in response to phone position
                                self.arrowNode?.eulerAngles.x = -pitch
                                self.arrowNode?.eulerAngles.y = -yaw
                            }
                            
                            
                        }
                        
                    }
                    
                    // Apply a forward velocity to the arrow
                    let arrowDirection = arrowTransform.columns.2
                    
                    if let node = lastNode{
                        let moveValue:Float = 100.0
                        let duration:TimeInterval = 5
                        var moveAction:SCNAction
                        //arrowNode.eulerAngles = SCNVector3Make(-arrowDirection.x, arrowDirection.y, -arrowDirection.z)
                        let power : Double = (startingPoint!.timeIntervalSinceNow * -1)
                        //arrowNode.simdRotation = simd_float4(arrowDirection.x, arrowDirection.x, arrowDirection.z, )
                        print("Power: \(power)")
                        //arrowNode.worldOrientation = SCNQuaternion()
                        var translation = matrix_identity_float4x4
                        
                        /**
                         Done using this source:
                         https://medium.com/macoclock/augmented-reality-911-transform-matrix-4x4-af91a9718246
                         
                         */
                        
                        //Translation on x-axis
                        translation.columns.1.y = cos(-1*Float(Double.pi)/2)
                        translation.columns.1.z = sin(-1*Float(Double.pi)/2)
                        
                        translation.columns.2.y = -1 * sin(-1*Float(Double.pi)/2)
                        translation.columns.2.z = cos(-1*Float(Double.pi)/2)

                        
                        
                        
                        let arrowVelocity = SCNVector3(arrowDirection.x * moveValue, arrowDirection.y * moveValue, arrowDirection.z * moveValue)
                        
                        arrowNode.physicsBody?.velocity = SCNVector3(x: -1 * arrowDirection.x * moveValue, y: -1 * arrowDirection.y * moveValue, z: -1 * arrowDirection.z * moveValue * Float(power))
                        
                        arrowNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
                        print("Current Frame Transform: \(currentFrame.camera.transform)")
                        
                        
                        /*
                        //moveAction = SCNAction.moveBy(x: Double(arrowDirection.x * moveValue) * -power, y: Double(arrowDirection.y * moveValue) * -power, z: Double((arrowDirection.z * moveValue)) * -power, duration: duration)
                        moveAction = SCNAction.moveBy(x: CGFloat(arrowVelocity.x) * -power, y: CGFloat(arrowVelocity.y) * -power, z: CGFloat(arrowVelocity.z) * -power, duration: duration)
                        
                        node.runAction(moveAction)*/
                    }
                }
            }
            
        }
    }

    func createArrowNode() -> SCNNode? {
        
        
        // Load the arrow scene
        guard let arrowScene = SCNScene(named: "arrow_horizontal.scn") else {
            print("Error: Unable to load arrow scene.")
            return nil
        }
        arrowScene.physicsWorld.contactDelegate = self
        // Retrieve the arrow node from the scene
        guard let arrowNode = arrowScene.rootNode.childNode(withName: "Cone", recursively: true) else {
            print("Error: Unable to find arrow node in the scene.")
            return nil
        }

        // Set the initial position of the arrow node in front of the camera
        if let currentFrame = sceneView.session.currentFrame {
        } else {
            print("Error: Unable to get current frame from AR session.")
        }
        
        // Setup camera position from existing scene
        if let cameraNodeTmp = arrowScene.rootNode.childNode(withName: "camera", recursively: true){
            cameraNode = cameraNodeTmp
            sceneView.scene.rootNode.addChildNode(cameraNode)
            }
                
        if let lighting = arrowScene.rootNode.childNode(withName: "Lighting", recursively: true){
            sceneView.scene.rootNode.addChildNode(lighting)
            }

        return arrowNode
    }
    

    
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        
        isFiring = true
                    
    }
    
    func configureArrowNode(_ arrowNode: SCNNode) { //set launch and trajectory of arrow
        // Configure physics
        sceneView.scene.rootNode.childNodes.filter({ $0.name == "Cone"}).forEach({$0.removeFromParentNode()})
        scene = SCNScene()
        scene?.physicsWorld.contactDelegate = self
        let physics = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape( geometry: arrowNode.geometry!, options: nil))
        physics.isAffectedByGravity = false
       

        physics.categoryBitMask = 0xFFFF
        physics.collisionBitMask = 0xFFFF
        physics.contactTestBitMask = 0xFFFF
        // Set appearance properties
        arrowNode.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
        arrowNode.physicsBody = physics
        arrowNode.physicsBody?.friction = frictionCoeff
        scene.rootNode.addChildNode(arrowNode)
        self.lastNode = arrowNode
    }

    @IBAction func handleTap(_ sender: UIButton) {
        
        // grab the current AR session frame from the scene, if possible
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        // setup some geometry for a simple plane
        let imagePlane = SCNPlane(width:sceneView.bounds.width/5,
                                  height:sceneView.bounds.height/5)
        
        // TODO - Add snapshot change distance
        if obj_material == 0 {
            imagePlane.firstMaterial?.diffuse.contents = sceneView.snapshot()}
        if obj_material == 1 {
            imagePlane.firstMaterial?.diffuse.contents = "Texture"
        }
        imagePlane.firstMaterial?.lightingModel = .constant
        
        // add the node to the scene
        let planeNode = SCNNode(geometry:imagePlane)
        planeNode.name = "target"
        sceneView.scene.rootNode.childNodes.filter({ $0.name == "target" }).forEach({ $0.removeFromParentNode() })
        
        let physics = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape( geometry: planeNode.geometry!, options: nil))
        physics.isAffectedByGravity = false
       

        physics.categoryBitMask = 0xFFFF
        physics.collisionBitMask = 0xFFFF
        physics.contactTestBitMask = 0xFFFF

        planeNode.physicsBody = physics
        let targetMass = CGFloat(1000000)
        planeNode.physicsBody?.mass = targetMass
        planeNode.physicsBody?.friction = frictionCoeff
        
        sceneView.scene.rootNode.addChildNode(planeNode)
        
        // update the node to be a bit in front of the camera inside the AR session
        
        // step one create a translation transform
        var translation = matrix_identity_float4x4
        
        //Rotates target by 90 degrees
        translation.columns.0.x = cos(Float(Double.pi/2))
        translation.columns.1.x = -1 * sin(Float(Double.pi/2))
        translation.columns.0.y = sin(Float(Double.pi/2))
        translation.columns.1.y = cos(Float(Double.pi/2))
        translation.columns.3.z = -300
        //print(translation)
        
        
        // step two, apply translation relative to camera for the node
        planeNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
         
    }

    
    //Function that handles arrow/target contact
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        
        let zeroVelocity = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
        
        func updateContact(){
            // Add
            self.score += 1
            
            DispatchQueue.main.async {
                self.updateScore()
            }
        }
        
        if let nameA = contact.nodeA.name,
            let nameB = contact.nodeB.name,
            nameA == "target" || nameB == "Cone"{ //If the ball makes contact with the hoop or the backboard
            print("------FIRST IF STATEMENT------")
            print("Contact made nodeA.X: \(contact.nodeA.simdPosition.x)")
            print("Contact made nodeA.Y: \(contact.nodeA.simdPosition.y)")
            
            print("Contact made nodeB.X: \(contact.nodeB.simdPosition.x)")
            print("Contact made nodeB.Y: \(contact.nodeB.simdPosition.y)")
            
            contact.nodeB.physicsBody?.velocity = SCNVector3(x: 0.0, y: 0.0, z: 0.0)

            // remove basketball from the scene
            updateContact()
        }
        
        if let nameB = contact.nodeB.name,
           let nameA = contact.nodeA.name,
            nameB == "target" || nameA == "Cone"{//If the ball makes contact with the hoop or the backboard
            print("------SECOND IF STATEMENT------")
            print("Contact made nodeA.X: \(contact.nodeA.simdPosition.x)")
            print("Contact made nodeA.Y: \(contact.nodeA.simdPosition.y)")
            
            print("Contact made nodeB.X: \(contact.nodeB.simdPosition.x)")
            print("Contact made nodeB.Y: \(contact.nodeB.simdPosition.y)")
            
            contact.nodeB.physicsBody?.velocity = SCNVector3(x: 0.0, y: 0.0, z: 0.0)

            updateContact()
        }
        
    }
    
    //Updates the score for the
    func updateScore(){
        //if(updating){return}
        // change the current object we are asking the participant to find
        // change the current object we are asking the participant to find
        
        scoreLabel.layer.add(animation, forKey: animationKey)
        scoreLabel.text = "Score: \(self.score)"
        
        if(self.score >= 50){
            // if here, End the game
            scoreLabel.layer.add(animation, forKey: animationKey)
            scoreLabel.text = "You Win!"
        }
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()

        configuration.planeDetection = [.horizontal, .vertical]

        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }
}
// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromCATransitionType(_ input: CATransitionType) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCATransitionType(_ input: String) -> CATransitionType {
    return CATransitionType(rawValue: input)
}
