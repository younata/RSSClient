import SpriteKit

final class RogueLikeViewController: UIViewController {
    let sceneView = SKView()
    let game: RogueLikeGame

    let exitButton = UIButton(type: .system)

    init() {
        self.game = RogueLikeGame(view: self.sceneView, levelGenerator: BoxLevelGenerator())
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
        self.view.backgroundColor = Theme.backgroundColor

        let menuView = UIView(forAutoLayout: ())
        menuView.backgroundColor = Theme.overlappingBackgroundColor
        self.view.addSubview(menuView)
        menuView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.sceneView.autoPinEdge(.top, to: .bottom, of: menuView)
        self.configureExitButton()

        menuView.addSubview(self.exitButton)
        self.exitButton.autoPinEdgesToSuperviewEdges(
            with: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16),
            excludingEdge: .trailing
        )

        let dpadGestureRecognizer = DirectionalGestureRecognizer(
            target: self,
            action: #selector(RogueLikeViewController.didRecognize(directionGestureRecognizer:))
        )
        self.sceneView.addGestureRecognizer(dpadGestureRecognizer)
        let panGestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(RogueLikeViewController.didPan(gestureRecognizer:))
        )
        self.sceneView.addGestureRecognizer(panGestureRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.game.start(bounds: self.sceneView.bounds)
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

    @objc private func exit() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc private func didRecognize(directionGestureRecognizer: DirectionalGestureRecognizer) {
        self.game.guidePlayer(direction: directionGestureRecognizer.direction)
    }

    var lastPanPoint: CGPoint? = nil
    @objc private func didPan(gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .recognized, .possible:
            self.lastPanPoint = gestureRecognizer.location(in: nil)
        case .changed:
            guard let lastPoint = self.lastPanPoint else { return }
            let currentPoint = gestureRecognizer.location(in: nil)
            self.game.panCamera(in: currentPoint - lastPoint)
            self.lastPanPoint = currentPoint
        case .ended, .cancelled, .failed:
            self.lastPanPoint = nil
        @unknown default:
            self.lastPanPoint = nil
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.landscape]
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(
            x: self.origin.x + (self.size.width / 2),
            y: self.origin.y + (self.size.height / 2)
        )
    }
}
