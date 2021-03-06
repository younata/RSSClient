import UIKit

public final class SwitchTableViewCell: UITableViewCell {
    public override var detailTextLabel: UILabel? { return nil }

    public let theSwitch: UISwitch = UISwitch(forAutoLayout: ())
    public var onTapSwitch: ((UISwitch) -> Void)?

    @objc private func didTapSwitch() {
        self.onTapSwitch?(self.theSwitch)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()

        self.accessibilityLabel = nil
        self.accessibilityValue = nil
        self.accessibilityHint = nil
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.theSwitch)
        self.theSwitch.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 5, left: 0, bottom: 4, right: 20),
            excludingEdge: .leading)

        self.theSwitch.addTarget(self, action: #selector(SwitchTableViewCell.didTapSwitch),
                                 for: .valueChanged)

        self.backgroundColor = Theme.backgroundColor
        self.textLabel?.textColor = Theme.textColor

        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button]
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }
}
