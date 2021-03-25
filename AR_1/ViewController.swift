//
//  ViewController.swift
//  AR_1
//
//  Created by wang.shuochen on 2021/02/19.
//

import UIKit
import ARKit
import Vision
import Foundation

@available(iOS 14.0, *)
class ViewController: UIViewController, ARSCNViewDelegate, ARCoachingOverlayViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
        
    //Store The Rotation Of The CurrentNode
    var currentAngleY: Float = 0.0
    private var distance: Float = 0
    var isRotating = false
    var state: String = ""
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    var currentFingerPosition: CGPoint?
    var strokeAnchorIDs: [UUID] = []
    var currentStrokeAnchorNode: SCNNode?
    
    //Kalman filter
    var measurements_1: [Double] = []
    var filter_1 = KalmanFilter(stateEstimatePrior: 0.0, errorCovariancePrior: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        let boxNode1 = addCube(position: SCNVector3(0.05,0,0), name: "box")
        let boxNode2 = addCube(position: SCNVector3(0,-0.05,0), name: "box2")
        let boxNode3 = addCube(position: SCNVector3(0,0.05,0), name: "box3")

        sceneView.scene.rootNode.addChildNode(boxNode1)
        sceneView.scene.rootNode.addChildNode(boxNode2)
        sceneView.scene.rootNode.addChildNode(boxNode3)

//        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(_:))))
        sceneView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(ViewController.handleMove(_:))))
        sceneView.addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(ViewController.handleRotate(_:))))
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
// use this method if you want to group everything into a new node, easier management
    func getMyNodes() -> [SCNNode] {
        var nodes: [SCNNode] = [SCNNode]()
        for node in sceneView.scene.rootNode.childNodes {
            nodes.append(node)
        }
        return nodes
    }
    
    func addCube(position: SCNVector3, name: String) -> SCNNode{
        let box = SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0)
        let boxNode = SCNNode(geometry: box)
//        let boxBody = SCNPhysicsBody(type: .dynamic, shape: nil)

        box.firstMaterial?.diffuse.contents = UIColor.red
        boxNode.position = position
//        boxBody.mass = 1
////        boxBody.categoryBitMask = CollisionBitmask.box.rawValue
//        boxNode.physicsBody = boxBody
//        boxBody.isAffectedByGravity = false

//        boxNode.rotation = SCNVector4Make(1, 1, 1, 1)
        boxNode.name = name
        return boxNode
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        print("session failed")
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func move_node(location:SCNVector3, nodeHit:SCNNode){
        let action = SCNAction.move(to: location, duration: 1)
        nodeHit.runAction(action)
    }
    
    // Tap gesture if you want to use it
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        guard let nodeHitTest = self.sceneView.hitTest(location, options: nil).first else { print("no node"); return }
        let nodeHit = nodeHitTest.node
        if let nodeName = nodeHit.name{
            if nodeName == "box"{
                //call translation method here
                let location2 = SCNVector3(x: 0.1, y: 0, z: 0)
                move_node(location: location2, nodeHit: nodeHit)
            }else{
            }
        }
    }
    
    /// pan gesture
    @objc func handleMove(_ gesture: UIPanGestureRecognizer) {

    //1. Get The Current Touch Point
    let location = gesture.location(in: self.sceneView)

    //2. Get The Next Feature Point Etc
    guard let nodeHitTest = self.sceneView.hitTest(location, options: nil).first else { print("no node"); return }
        
    let nodeHit = nodeHitTest.node
//    nodeHit.name = "hit"
    let original_x = nodeHitTest.node.position.x
    let original_y = nodeHitTest.node.position.y
    //3. Convert To World Coordinates
    let worldTransform = nodeHitTest.simdWorldCoordinates
    //4. Apply To The Node
////    nodeHit.position = SCNVector3(worldTransform.x, worldTransform.y, 0)
    nodeHit.position = SCNVector3(worldTransform.x, worldTransform.y, 0)

    for node in nodeHit.parent!.childNodes {
        if node.name != nodeHit.name {
            let old_x = node.position.x
            let old_y = node.position.y
            node.position = SCNVector3((nodeHit.simdPosition.x - original_x + old_x), (nodeHit.simdPosition.y - original_y + old_y), 0)
            }
        }
        
    }
    
    // Rotate action
    @objc func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        guard let nodeHitTest = self.sceneView.hitTest(location, options: nil).first else { print("no node"); return }
        let nodeHit = nodeHitTest.node
        //call rotation method here
        if gesture.state == UIGestureRecognizer.State.changed {
            //1. Get The Current Rotation From The Gesture
            let rotation = Float(gesture.rotation)

            //2. If The Gesture State Has Changed Set The Nodes EulerAngles.y
            if gesture.state == .changed{
                isRotating = true
                nodeHit.eulerAngles.y = currentAngleY + rotation
            }

            //3. If The Gesture Has Ended Store The Last Angle Of The Cube
            if(gesture.state == .ended) {
                currentAngleY = nodeHit.eulerAngles.y
                isRotating = false
            }
        }else{
    }

    }
    
    // MARK: Methods
    
    func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil {
            self.state = "no camera"
            return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        var thumbTip: CGPoint?
        var thumbIp: CGPoint?
        var thumbMp: CGPoint?
        var thumbCmc: CGPoint?
        
        var indexTip: CGPoint?
        var indexDip: CGPoint?
        var indexPip: CGPoint?
        var indexMcp: CGPoint?
        
        var middleTip: CGPoint?
        var middleDip: CGPoint?
        var middlePip: CGPoint?
        var middleMcp: CGPoint?
        
        var ringTip: CGPoint?
        var ringDip: CGPoint?
        var ringPip: CGPoint?
        var ringMcp: CGPoint?
        
        var littleTip: CGPoint?
        var littleDip: CGPoint?
        var littlePip: CGPoint?
        var littleMcp: CGPoint?
        
        var wrist: CGPoint?
        
        let scale = CMTimeScale(NSEC_PER_SEC)
        let pts = CMTime(value: CMTimeValue(sceneView.session.currentFrame!.timestamp * Double(scale)),
                         timescale: scale)
        var timingInfo = CMSampleTimingInfo(duration: CMTime.invalid,
                                            presentationTimeStamp: pts,
                                            decodeTimeStamp: CMTime.invalid)
        
        let CMFCV = CMFormatDescription.make(from: pixbuff!)!
        var CMSCV = CMSampleBuffer.make(from: pixbuff!, formatDescription: CMFCV, timingInfo: &timingInfo)
        let handler = VNImageRequestHandler(cmSampleBuffer: CMSCV!, orientation: .right, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                self.state = "no hand"
                return
            }
            // Get points for thumb and index finger.
            let thumbPoints = try observation.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.thumb)
            let indexFingerPoints = try observation.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.littleFinger)
            let wristPoints = try observation.recognizedPoints(forGroupKey: .all)
            
            // Look for tip points.
            guard let thumbTipPoint = thumbPoints[VNHumanHandPoseObservation.JointName.thumbTip],
                  let thumbIpPoint = thumbPoints[VNHumanHandPoseObservation.JointName.thumbIP],
                  let thumbMpPoint = thumbPoints[VNHumanHandPoseObservation.JointName.thumbMP],
                  let thumbCMCPoint = thumbPoints[VNHumanHandPoseObservation.JointName.thumbCMC] else {
                self.state = "no thumb"
                return
            }
            
            guard let indexTipPoint = indexFingerPoints[VNHumanHandPoseObservation.JointName.indexTip],
                  let indexDipPoint = indexFingerPoints[VNHumanHandPoseObservation.JointName.indexDIP],
                  let indexPipPoint = indexFingerPoints[VNHumanHandPoseObservation.JointName.indexPIP],
                  let indexMcpPoint = indexFingerPoints[VNHumanHandPoseObservation.JointName.indexMCP] else {
                self.state = "no index"
                return
            }
            
            guard let middleTipPoint = middleFingerPoints[VNHumanHandPoseObservation.JointName.middleTip],
                  let middleDipPoint = middleFingerPoints[VNHumanHandPoseObservation.JointName.middleDIP],
                  let middlePipPoint = middleFingerPoints[VNHumanHandPoseObservation.JointName.middlePIP],
                  let middleMcpPoint = middleFingerPoints[VNHumanHandPoseObservation.JointName.middleMCP] else {
                self.state = "no middle"
                return
            }
            
            guard let ringTipPoint = ringFingerPoints[VNHumanHandPoseObservation.JointName.ringTip],
                  let ringDipPoint = ringFingerPoints[VNHumanHandPoseObservation.JointName.ringDIP],
                  let ringPipPoint = ringFingerPoints[VNHumanHandPoseObservation.JointName.ringPIP],
                  let ringMcpPoint = ringFingerPoints[VNHumanHandPoseObservation.JointName.ringMCP] else {
                self.state = "no ring"
                return
            }
            
            guard let littleTipPoint = littleFingerPoints[VNHumanHandPoseObservation.JointName.littleTip],
                  let littleDipPoint = littleFingerPoints[VNHumanHandPoseObservation.JointName.littleDIP],
                  let littlePipPoint = littleFingerPoints[VNHumanHandPoseObservation.JointName.littlePIP],
                  let littleMcpPoint = littleFingerPoints[VNHumanHandPoseObservation.JointName.littleMCP] else {
                self.state = "no little"
                return
            }
            guard let wristPoint = wristPoints[.handLandmarkKeyWrist] else {
                self.state = "no wrist"
                return
            }
            
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            thumbIp = CGPoint(x: thumbIpPoint.location.x, y: 1 - thumbIpPoint.location.y)
            thumbMp = CGPoint(x: thumbMpPoint.location.x, y: 1 - thumbMpPoint.location.y)
            thumbCmc = CGPoint(x: thumbCMCPoint.location.x, y: 1 - thumbCMCPoint.location.y)
            
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            indexDip = CGPoint(x: indexDipPoint.location.x, y: 1 - indexDipPoint.location.y)
            indexPip = CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y)
            indexMcp = CGPoint(x: indexMcpPoint.location.x, y: 1 - indexMcpPoint.location.y)
            
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            middleDip = CGPoint(x: middleDipPoint.location.x, y: 1 - middleDipPoint.location.y)
            middlePip = CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y)
            middleMcp = CGPoint(x: middleMcpPoint.location.x, y: 1 - middleMcpPoint.location.y)
            
            ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            ringDip = CGPoint(x: ringDipPoint.location.x, y: 1 - ringDipPoint.location.y)
            ringPip = CGPoint(x: ringPipPoint.location.x, y: 1 - ringPipPoint.location.y)
            ringMcp = CGPoint(x: ringMcpPoint.location.x, y: 1 - ringMcpPoint.location.y)
            
            littleTip = CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y)
            littleDip = CGPoint(x: littleDipPoint.location.x, y: 1 - littleDipPoint.location.y)
            littlePip = CGPoint(x: littlePipPoint.location.x, y: 1 - littlePipPoint.location.y)
            littleMcp = CGPoint(x: littleMcpPoint.location.x, y: 1 - littleMcpPoint.location.y)
            
            wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
            
            let indexTip2 = VNImagePointForNormalizedPoint(indexTip!, Int(self.sceneView.bounds.size.width), Int(self.sceneView.bounds.size.height))
            self.state = "normal"
            
// Translation using hand gesture
            guard let nodeHitTest = self.sceneView.hitTest(indexTip2, options: nil).first else { return }

            let nodeHit = nodeHitTest.node
            let original_x = nodeHitTest.node.position.x
            let original_y = nodeHitTest.node.position.y
            //3. Convert To World Coordinates
            let worldTransform = nodeHitTest.simdWorldCoordinates
            //4. Apply To The Node
            nodeHit.position = SCNVector3(worldTransform.x, worldTransform.y, 0)

            for node in nodeHit.parent!.childNodes {
                if node.name != nil{
                    if node.name != nodeHit.name {
                        let old_x = node.position.x
                        let old_y = node.position.y
                        node.position = SCNVector3((nodeHit.simdPosition.x - original_x + old_x), (nodeHit.simdPosition.y - original_y + old_y), 0)
                    }
                }
            }

//  This is the code for rotation using hand gesture, if you want to be able to do both
//  rotation and translation you need to add more hand gestures classifier
//            guard let nodeHitTest = self.sceneView.hitTest(indexTip2, options: nil).first else { print("no node"); return }
//            let nodeHit = nodeHitTest.node
//            //call rotation method here
//
//            //2. If The Gesture State Has Changed Set The Nodes EulerAngles.y
//            nodeHit.eulerAngles.y = currentAngleY + 0.1
//            currentAngleY += 0.1
//            print(nodeHit.eulerAngles.y )
            
        } catch {
            let error = (error)
            print(error)
        }
    }

        
// ray cast method possible implementation
//        guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .any) else {
//           return
//        }
//
//        let results = sceneView.session.raycast(query)
//        guard let hitTestResult = results.first else {
//           print("No surface found")
//           return
//        }
//        print(hitTestResult)
        
//        let results = self.sceneView.hitTest(gesture.location(in: gesture.view), types: ARHitTestResult.ResultType.featurePoint)
//        guard let result: ARHitTestResult = results.first else {
//            return
//        }
//        let tappedNode = self.sceneView.hitTest(gesture.location(in: gesture.view), options: [:])
//
//        if !tappedNode.isEmpty {
//            let node = tappedNode[0].node
////            print(node)
//
//        } else {
//
//            return
//
//        }

    
    // MARK: - SCNSceneRendererDelegate
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async {
           self.updateCoreML()
        }
    }
    
}

// MARK: - ARSCNViewDelegate
    
//     Override to create and configure nodes for anchors added to the view's session.
@available(iOS 14.0, *)
extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) {

    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime scene: SCNScene, atTime time: TimeInterval) {

    }
}

extension CMSampleBuffer {
  static func make(from pixelBuffer: CVPixelBuffer, formatDescription: CMFormatDescription, timingInfo: inout CMSampleTimingInfo) -> CMSampleBuffer? {
    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil,
                                       refcon: nil, formatDescription: formatDescription, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
    return sampleBuffer
  }
}

extension CMFormatDescription {
  static func make(from pixelBuffer: CVPixelBuffer) -> CMFormatDescription? {
    var formatDescription: CMFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
    return formatDescription
  }
}

// MARK:- ARSessionDelegate

@available(iOS 14.0, *)
extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        updateCoreML()
    }
    
}

