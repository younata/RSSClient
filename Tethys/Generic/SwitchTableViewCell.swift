import UIKit

public final class SwitchTableViewCell: UITableViewCell {
    private var _textLabel = UILabel(forAutoLayout: ())
    public override var textLabel: UILabel? { return self._textLabel }

    public override var detailTextLabel: UILabel? { return nil }

    public let theSwitch: UISwitch = UISwitch(forAutoLayout: ())
    public var onTapSwitch: ((UISwitch) -> Void)?

    @objc private func didTapSwitch() {
        self.onTapSwitch?(self.theSwitch)
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self._textLabel)
        self._textLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 4, left: 15, bottom: 4, right: 0),
            excludingEdge: .trailing)
        self.contentView.addSubview(self.theSwitch)
        self.theSwitch.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 5, left: 0, bottom: 4, right: 15),
            excludingEdge: .leading)
        self.theSwitch.autoPinEdge(.leading, to: .trailing, of: self._textLabel)

        self.theSwitch.addTarget(self, action: #selector(SwitchTableViewCell.didTapSwitch),
                                 for: .valueChanged)

        self.backgroundColor = Theme.backgroundColor
        self.textLabel?.textColor = Theme.textColor
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }
}
