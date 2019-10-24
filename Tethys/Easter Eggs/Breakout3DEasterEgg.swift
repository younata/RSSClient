import SceneKit
import PureLayout

// swiftlint:disable file_length

private let BreakoutLength: CGFloat = 100

final class Breakout3DEasterEggViewController: UIViewController, Breakout3DDelegate {
    let sceneView = SCNView()
    private(set) var breakoutGame: Breakout3D?

    let exitButton = UIButton(type: .system)
    let scoreLabel = UILabel(forAutoLayout: ())

    private let mainQueue: OperationQueue

    init(mainQueue: OperationQueue) {
        self.mainQueue = mainQueue
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.overrideUserInterfaceStyle = .dark

        self.sceneView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.sceneView)
        self.sceneView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)

        let scoreContainer = UIView(forAutoLayout: ())
        scoreContainer.backgroundColor = Theme.overlappingBackgroundColor
        self.view.addSubview(scoreContainer)
        scoreContainer.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        self.sceneView.autoPinEdge(.top, to: .bottom, of: scoreContainer)

        self.exitButton.translatesAutoresizingMaskIntoConstraints = false
        scoreContainer.addSubview(self.exitButton)

        self.configureExitButton()

        scoreContainer.addSubview(self.scoreLabel)
        self.configureScoreLabel()

        self.scoreLabel.autoCenterInSuperview()
        self.scoreLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        self.scoreLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        self.scoreLabel.autoPinEdge(.leading, to: .trailing, of: self.exitButton, withOffset: 8,
                               relation: .greaterThanOrEqual)
        self.exitButton.autoPinEdge(.top, to: .top, of: self.scoreLabel)
        self.exitButton.autoPinEdge(.bottom, to: .bottom, of: self.scoreLabel)
        self.exitButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)

        let scene = SCNScene()
        self.sceneView.scene = scene
        self.sceneView.autoenablesDefaultLighting = false
        self.sceneView.isAccessibilityElement = true
        self.sceneView.accessibilityTraits = [.allowsDirectInteraction]
        self.sceneView.accessibilityLabel = NSLocalizedString("Breakout3D_Title", comment: "")
        self.sceneView.accessibilityHint = NSLocalizedString("Breakout3D_Accessibility_SceneView_Hint",
                                                             comment: "")

        self.breakoutGame = Breakout3D(scene: scene)
        self.breakoutGame?.delegate = self

        self.view.backgroundColor = Theme.backgroundColor
    }

    private func configureExitButton() {
        self.exitButton.addTarget(self, action: #selector(exit), for: .touchUpInside)
        self.exitButton.setTitle(NSLocalizedString("Generic_Close", comment: ""), for: .normal)
        self.exitButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.exitButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        self.exitButton.setTitleColor(Theme.highlightColor, for: .normal)
        self.exitButton.isAccessibilityElement = true
        self.exitButton.accessibilityTraits = [.button]
        self.exitButton.accessibilityLabel = NSLocalizedString("Generic_Close", comment: "")
    }

    private func configureScoreLabel() {
        self.scoreLabel.font = UIFont.preferredFont(forTextStyle: .body)
        self.scoreDidUpdate(to: 0)
        self.scoreLabel.textColor = Theme.textColor
        self.scoreLabel.isAccessibilityElement = true
        self.scoreLabel.accessibilityTraits = [.updatesFrequently]
        self.scoreLabel.accessibilityLabel = NSLocalizedString("Breakout3D_Accessibility_ScoreLabel", comment: "")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.breakoutGame?.resetGame(
            width: self.sceneView.bounds.size.width / 10,
            height: self.sceneView.bounds.size.height / 10
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.touchesHappened(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        self.touchesHappened(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.touchesHappened(touches)
    }

    private func touchesHappened(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self.sceneView)

        let width = self.view.bounds.size.width / 10
        let height = self.view.bounds.size.height / 10

        let x = (location.x / 10) - (width / 2)
        let y = (location.y / 10) - (height / 2)

        self.breakoutGame?.movePaddle(x: x, y: -y)
    }

    @objc private func exit() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func breakout3d(_ breakout3d: Breakout3D, didEndGame win: Bool) {
        self.mainQueue.addOperation {
            breakout3d.resetGame(width: self.sceneView.bounds.size.width, height: self.sceneView.bounds.size.height)
        }
    }

    func breakout3dDidUpdateScore(_ breakout3d: Breakout3D) {
        self.mainQueue.addOperation {
            self.scoreDidUpdate(to: breakout3d.score)
        }
    }

    private func scoreDidUpdate(to score: Int) {
        self.scoreLabel.text = String.localizedStringWithFormat(
            NSLocalizedString("Breakout3D_Points", comment: ""),
            score
        )
        self.scoreLabel.accessibilityLabel = NSLocalizedString("Breakout3D_Accessibility_ScoreLabel", comment: "")
        self.scoreLabel.accessibilityValue = self.scoreLabel.text
    }
}

protocol Breakout3DDelegate: class {
    func breakout3d(_ breakout3d: Breakout3D, didEndGame win: Bool)
    func breakout3dDidUpdateScore(_ breakout3d: Breakout3D)
}

final class Breakout3D: NSObject, SCNPhysicsContactDelegate {
    let gameNode = SCNNode()

    private(set) var score: Int = 0

    private let cameraNode = SCNNode()

    weak var delegate: Breakout3DDelegate?

    let scene: SCNScene
    private var physicsWorld: SCNPhysicsWorld { return self.scene.physicsWorld }

    private var width: CGFloat = 32
    private var height: CGFloat = 48

    let ballNodeName = "ball"
    let paddleNodeName = "paddle"

    let wallCategory =     0b10000
    let rearWallCategory = 0b01000
    let brickCategory =    0b00100
    let ballCategory =     0b00010
    let paddleCategory =   0b00001

    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let gameEventFeedbackGenerator = UINotificationFeedbackGenerator()

    init(scene: SCNScene) {
        self.scene = scene
        super.init()

        let camera = SCNCamera()
        camera.zFar = 10000
        self.scene.rootNode.addChildNode(self.cameraNode)
        self.scene.background.contents = UIColor.black
        self.cameraNode.camera = camera
        self.cameraNode.position = SCNVector3(0, 0, 50)

        self.scene.rootNode.addChildNode(self.gameNode)

        self.physicsWorld.gravity = SCNVector3Zero
        self.physicsWorld.contactDelegate = self
        self.physicsWorld.removeAllBehaviors()

        self.scene.isPaused = true
    }

    func movePaddle(x: CGFloat, y: CGFloat) {
        guard let paddle = self.gameNode.childNode(withName: self.paddleNodeName, recursively: false) else {
            return
        }
        paddle.position = SCNVector3(x, y, CGFloat(paddle.position.z))
    }

    func resetGame(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height

        if let box = self.gameNode.geometry as? SCNBox {
            box.width = width
            box.height = height
        }

        self.gameNode.childNodes.forEach {
            $0.removeFromParentNode()
        }

        let ball = self.ballNode()
        let paddle = self.paddleNode()
        self.gameNode.addChildNode(ball)
        self.gameNode.addChildNode(paddle)
        self.generateBricks().forEach(self.gameNode.addChildNode)
        self.wallNodes().forEach(self.gameNode.addChildNode)

        self.physicsWorld.contactDelegate = self

        self.scene.isPaused = false

        ball.physicsBody?.velocity = SCNVector3(10, sqrt(22), 16)

        self.score = 0

        self.delegate?.breakout3dDidUpdateScore(self)
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        guard nodeA.categoryBitMask == self.ballCategory || nodeB.categoryBitMask == self.ballCategory else { return }

        self.impactGenerator.prepare()
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        guard nodeA.categoryBitMask == self.ballCategory || nodeB.categoryBitMask == self.ballCategory else { return }

        let ballNode: SCNNode
        if nodeA.categoryBitMask == self.ballCategory {
            ballNode = nodeA
        } else {
            ballNode = nodeB
        }
        let intensity = min(1, 1 / pow((CGFloat(ballNode.position.z) / (BreakoutLength / 2)) + 1, 2))
        self.impactGenerator.impactOccurred(intensity: intensity)

        if ((nodeA.categoryBitMask | nodeB.categoryBitMask) & self.brickCategory) != 0 {
            // remove whichever is the brick.
            let node: SCNNode
            if nodeA.categoryBitMask == self.brickCategory {
                node = nodeA
            } else if nodeB.categoryBitMask == self.brickCategory {
                node = nodeB
            } else {
                // Shouldn't happen, but hey.
                return
            }
            self.score += 1
            node.removeFromParentNode()
            if self.gameNode.childNodes(passingTest: { (node, end) -> Bool in
                if node.categoryBitMask & self.brickCategory != 0 {
                    end.assign(repeating: true, count: 1)
                    return true
                }
                return false
            }).isEmpty {
                self.delegate?.breakout3d(self, didEndGame: true)
                self.gameEventFeedbackGenerator.notificationOccurred(.success)
            }
            self.delegate?.breakout3dDidUpdateScore(self)
            return
        }
//        if ((nodeA.categoryBitMask | nodeB.categoryBitMask) & self.rearWallCategory) != 0 {
//            self.delegate?.breakout3d(self, didEndGame: false)
//            print("Game over?")
//            self.scene.isPaused = true
//            self.gameEventFeedbackGenerator.notificationOccurred(.error)
//            return
//        }
    }

    private func ballNode() -> SCNNode {
        let node = SCNNode()
        node.name = self.ballNodeName
        node.categoryBitMask = self.ballCategory
        let sphere = SCNSphere(radius: 1)
        node.geometry = sphere
        node.geometry?.firstMaterial?.emission.contents = UIColor.white
        node.worldPosition = SCNVector3(0, 0, -60)

        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: sphere, options: nil))
        physicsBody.restitution = 1.0
        physicsBody.damping = 0
        physicsBody.angularDamping = 0
        physicsBody.friction = 0
        physicsBody.rollingFriction = 0
        physicsBody.categoryBitMask = node.categoryBitMask
        physicsBody.contactTestBitMask = self.rearWallCategory | self.brickCategory |
            self.paddleCategory | self.wallCategory
        node.physicsBody = physicsBody

        let light = SCNLight()
        light.type = .omni
        light.color = UIColor.white
        light.intensity = 2000
        light.castsShadow = true
        node.light = light

        return node
    }

    private func paddleNode() -> SCNNode {
        let node = SCNNode()
        node.name = self.paddleNodeName
        node.categoryBitMask = self.paddleCategory
        node.position = SCNVector3(0, 0, -1)
        let plane = SCNPlane(width: self.width / 5, height: self.height / 5)
        plane.firstMaterial?.diffuse.contents = UIColor.systemIndigo.withAlphaComponent(0.7)
        plane.firstMaterial?.isDoubleSided = true
        node.geometry = plane
        self.addKinematicPhysics(to: node)
        node.physicsBody?.categoryBitMask = node.categoryBitMask
        return node
    }

    private func generateBricks() -> [SCNNode] {
        let rows = 5
        let cols = 5

        let distanceBetweenNodes: CGFloat = 3
        let nodeWidth = (self.width - (CGFloat(rows + 1) * distanceBetweenNodes)) / CGFloat(rows)
        let nodeHeight = (self.height - (CGFloat(cols + 1) * distanceBetweenNodes)) / CGFloat(cols)
        let nodeDepth: CGFloat = 2

        let colors: [UIColor] = [
            UIColor.systemRed,
            UIColor.systemOrange,
            UIColor.systemYellow,
            UIColor.systemGreen,
            UIColor.systemBlue,
            UIColor.systemPurple
        ]

        return (0..<colors.count).flatMap { z -> [SCNNode] in
            let nodeColor = colors[colors.count - (z + 1)]
            let zPosition: CGFloat = (CGFloat(z + 1) * distanceBetweenNodes) + (nodeDepth / 2) - BreakoutLength
            return (0..<rows).flatMap { x -> [SCNNode] in
                let xPosition: CGFloat = (CGFloat(x + 1) * distanceBetweenNodes) + (nodeWidth / 2)
                    + (CGFloat(x) * nodeWidth)
                    - (self.width / 2)
                return (0..<cols).map { y -> SCNNode in
                    let yPosition = (CGFloat(y + 1) * distanceBetweenNodes) + (nodeHeight / 2)
                        + (CGFloat(y) * nodeHeight)
                        - (self.height / 2)

                    let node = SCNNode()
                    node.name = "brick"
                    node.categoryBitMask = self.brickCategory
                    node.position = SCNVector3(xPosition, yPosition, zPosition)
                    node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)

                    let box = SCNBox(width: nodeWidth, height: nodeHeight, length: nodeDepth, chamferRadius: 0)
                    box.materials.forEach { material in
                        material.diffuse.contents = nodeColor
                    }
                    node.geometry = box
                    self.addKinematicPhysics(to: node)
                    node.physicsBody?.categoryBitMask = node.categoryBitMask
                    return node
                }
            }
        }
    }

    private func wallNodes() -> [SCNNode] {
        let backNode = SCNNode()
        backNode.geometry = SCNPlane(width: self.width, height: self.height)
        backNode.position = SCNVector3(0, 0, -BreakoutLength)

        let topNode = SCNNode()
        topNode.geometry = SCNPlane(width: self.width, height: BreakoutLength)
        topNode.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
        topNode.position = SCNVector3(0, self.height / 2, -BreakoutLength / 2)

        let bottomNode = SCNNode()
        bottomNode.geometry = SCNPlane(width: self.width, height: BreakoutLength)
        bottomNode.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        bottomNode.position = SCNVector3(0, -self.height / 2, -BreakoutLength / 2)

        let leftNode = SCNNode()
        leftNode.geometry = SCNPlane(width: BreakoutLength, height: self.height)
        leftNode.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        leftNode.position = SCNVector3(self.width / 2, 0, -BreakoutLength / 2)

        let rightNode = SCNNode()
        rightNode.geometry = SCNPlane(width: BreakoutLength, height: self.height)
        rightNode.eulerAngles = SCNVector3(0, -CGFloat.pi / 2, 0)
        rightNode.position = SCNVector3(-self.width / 2, 0, -BreakoutLength / 2)

        let resetNode = SCNNode()
        resetNode.geometry = SCNPlane(width: self.width, height: self.height)
        resetNode.categoryBitMask = self.rearWallCategory

        let nodes = [backNode, topNode, bottomNode, leftNode, rightNode, resetNode]

        nodes.forEach { node in
            node.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
            node.geometry?.firstMaterial?.isDoubleSided = true

            self.addKinematicPhysics(to: node)
            node.physicsBody?.categoryBitMask = node.categoryBitMask | self.wallCategory
        }

        resetNode.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        backNode.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.3, alpha: 1.0)

        return nodes
    }

    private func addKinematicPhysics(to node: SCNNode) {
        let physicsBody = SCNPhysicsBody(type: .kinematic,
                                          shape: SCNPhysicsShape(geometry: node.geometry!, options: nil))
        physicsBody.restitution = 1.0
        physicsBody.damping = 0
        physicsBody.angularDamping = 0
        physicsBody.friction = 0
        physicsBody.rollingFriction = 0

        node.physicsBody = physicsBody
    }
}
