import UIKit

public final class ArticleListHeaderCell: UITableViewCell {
    public let summary = UILabel(forAutoLayout: ())
    public let iconView = UIImageView(forAutoLayout: ())

    fileprivate let footer = UIView(forAutoLayout: ())

    public private(set) var iconWidth: NSLayoutConstraint!
    public private(set) var iconHeight: NSLayoutConstraint!

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public func configure(summary: String, image: UIImage?) {
        self.summary.text = summary
        if let image = image {
            self.iconView.image = image
            let scaleRatio = 60 / image.size.width
            self.iconWidth.constant = 60
            self.iconHeight.constant = image.size.height * scaleRatio
        } else {
            self.iconView.image = nil
            self.iconWidth.constant = 0
            self.iconHeight.constant = 0
        }
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.summary)
        self.contentView.addSubview(self.iconView)
        self.contentView.addSubview(self.footer)

        self.summary.numberOfLines = 0
        self.summary.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)

        self.summary.autoPinEdge(toSuperviewEdge: .leading, withInset: 8)
        self.summary.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        self.summary.autoPinEdge(.bottom, to: .top, of: self.footer, withOffset: -8)
        self.summary.autoPinEdge(.trailing, to: .leading, of: self.iconView, withOffset: -8)

        self.iconView.autoPinEdge(.top, to: .top, of: self.contentView,
                                  withOffset: 0, relation: .greaterThanOrEqual)
        self.iconView.autoPinEdge(.bottom, to: .top, of: self.footer,
                                  withOffset: 0, relation: .lessThanOrEqual)
        self.iconView.autoAlignAxis(toSuperviewAxis: .horizontal)
        self.iconView.autoPinEdge(toSuperviewEdge: .trailing)

        self.iconWidth = self.iconView.autoSetDimension(.width, toSize: 0)
        self.iconHeight = self.iconView.autoSetDimension(.height, toSize: 0)

        self.footer.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 0, bottom: -1, right: 0),
                                                 excludingEdge: .top)
        self.footer.autoSetDimension(.height, toSize: 2)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ArticleListHeaderCell: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.summary.textColor = themeRepository.textColor
        self.footer.backgroundColor = themeRepository.textColor

        self.backgroundColor = themeRepository.backgroundColor
    }
}
