import UIKit

public protocol FeedDetailViewDelegate: class {
    func feedDetailView(_ feedDetailView: FeedDetailView, urlDidChange url: URL)
    func feedDetailView(_ feedDetailView: FeedDetailView, tagsDidChange tags: [String])
    func feedDetailView(_ feedDetailView: FeedDetailView,
                        editTag tag: String?, completion: @escaping (String) -> Void)
}

public final class FeedDetailView: UIView {
    private let mainStackView = UIStackView(forAutoLayout: ())

    public let titleLabel = UILabel(forAutoLayout: ())
    public let urlField = UITextField(forAutoLayout: ())
    public let summaryLabel = UILabel(forAutoLayout: ())

    public let addTagButton = UIButton(type: .system)
    public let tagsList = ActionableTableView(forAutoLayout: ())

    public var title: String { return self.titleLabel.text ?? "" }
    public var url: URL? { return URL(string: self.urlField.text ?? "") }
    public var summary: String { return self.summaryLabel.text ?? "" }
    public fileprivate(set) var tags: [String] = [] {
        didSet { self.tagsList.recalculateHeightConstraint() }
    }

    public var maxHeight: CGFloat {
        get { return self.tagsList.maxHeight }
        set { self.tagsList.maxHeight = newValue }
    }
    public weak var delegate: FeedDetailViewDelegate?

    public func configure(title: String, url: URL, summary: String, tags: [String]) {
        self.titleLabel.text = title
        self.summaryLabel.text = summary

        let delegate = self.delegate
        self.delegate = nil
        self.urlField.text = url.absoluteString
        self.urlField.accessibilityValue = url.absoluteString
        self.delegate = delegate

        self.titleLabel.accessibilityLabel = NSLocalizedString(
            "FeedViewController_Accessibility_TableHeader_Title_Label", comment: ""
        )
        self.titleLabel.accessibilityValue = title

        self.summaryLabel.accessibilityLabel = NSLocalizedString(
            "FeedViewController_Accessibility_TableHeader_Summary_Label", comment: ""
        )
        self.summaryLabel.accessibilityValue = summary

        self.tags = tags
        self.tagsList.reloadData()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.mainStackView)

        self.mainStackView.axis = .vertical
        self.mainStackView.spacing = 6
        self.mainStackView.distribution = .equalSpacing
        self.mainStackView.alignment = .center

        self.mainStackView.autoPinEdge(toSuperviewEdge: .leading)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .trailing)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .top, withInset: 84)
        self.mainStackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20, relation: .greaterThanOrEqual)

        self.mainStackView.addArrangedSubview(self.titleLabel)
        self.mainStackView.addArrangedSubview(self.urlField)
        self.mainStackView.addArrangedSubview(UIView()) // to give a little extra space between url and summary
        self.mainStackView.addArrangedSubview(self.summaryLabel)
        self.mainStackView.addArrangedSubview(self.tagsList)

        self.addTagButton.translatesAutoresizingMaskIntoConstraints = false
        self.tagsList.setActions([UIView(), self.addTagButton])

        self.urlField.delegate = self

        self.tagsList.tableView.register(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tagsList.tableView.delegate = self
        self.tagsList.tableView.dataSource = self
        self.tagsList.tableView.estimatedRowHeight = 80

        self.summaryLabel.numberOfLines = 0
        self.titleLabel.numberOfLines = 0

        for view in ([self.titleLabel, self.summaryLabel, self.urlField] as [UIView]) {
            view.autoPinEdge(toSuperviewEdge: .leading, withInset: 40)
            view.autoPinEdge(toSuperviewEdge: .trailing, withInset: 40)
        }

        self.tagsList.autoPinEdge(toSuperviewEdge: .leading)
        self.tagsList.autoPinEdge(toSuperviewEdge: .trailing)

        self.addTagButton.setTitle(NSLocalizedString("FeedViewController_Actions_AddTag", comment: ""), for: .normal)
        self.addTagButton.addTarget(self, action: #selector(FeedDetailView.didTapAddTarget), for: .touchUpInside)
        self.urlField.textColor = UIColor.gray

        [self.titleLabel, self.urlField, self.summaryLabel, self.addTagButton].forEach { view in
            view.isAccessibilityElement = true
        }
        self.titleLabel.accessibilityTraits = [.staticText]
        self.summaryLabel.accessibilityTraits = [.staticText]
        self.addTagButton.accessibilityTraits = [.button]
        self.addTagButton.accessibilityLabel = NSLocalizedString("FeedViewController_Actions_AddTag", comment: "")

        self.urlField.accessibilityLabel = NSLocalizedString("FeedViewController_Accessibility_TableHeader_URL_Label",
                                                             comment: "")

        self.applyTheme()
    }

    private func applyTheme() {
        self.backgroundColor = Theme.backgroundColor

        self.tagsList.tableView.backgroundColor = Theme.backgroundColor
        self.tagsList.tableView.separatorColor = Theme.separatorColor

        self.titleLabel.textColor = Theme.textColor
        self.summaryLabel.textColor = Theme.textColor
        self.addTagButton.setTitleColor(Theme.highlightColor, for: .normal)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func layoutSubviews() {
        self.titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        self.summaryLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        self.urlField.font = UIFont.preferredFont(forTextStyle: .subheadline)

        super.layoutSubviews()
    }

    @objc private func didTapAddTarget() {
        self.delegate?.feedDetailView(self, editTag: nil) { newTag in
            self.tags.append(newTag)
            let indexPath = IndexPath(row: self.tags.count - 1, section: 0)
            self.tagsList.tableView.insertRows(at: [indexPath], with: .automatic)
            self.tagsList.recalculateHeightConstraint()
            self.delegate?.feedDetailView(self, tagsDidChange: self.tags)
        }
    }
}

extension FeedDetailView: UITextFieldDelegate {
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        let text = NSString(string: textField.text ?? "").replacingCharacters(in: range, with: string)
        if let url = URL(string: text), url.scheme != nil {
            self.delegate?.feedDetailView(self, urlDidChange: url)
        }
        return true
    }
}

extension FeedDetailView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tags.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.textLabel?.text = self.tags[indexPath.row]
        cell.accessibilityTraits = [.button]
        cell.accessibilityLabel = NSLocalizedString("FeedViewController_Accessibility_Cell_Label", comment: "")
        cell.accessibilityValue = self.tags[indexPath.row]
        return cell
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { return true }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {}
}

extension FeedDetailView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt
                                                    indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIContextualAction(style: .destructive, title: deleteTitle) { _, _, handler in
            self.tags.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.delegate?.feedDetailView(self, tagsDidChange: self.tags)
            handler(true)
        }
        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UIContextualAction(style: .normal, title: editTitle) { _, _, handler in
            let tag = self.tags[indexPath.row]

            self.delegate?.feedDetailView(self, editTag: tag) { newTag in
                self.tags[indexPath.row] = newTag
                tableView.reloadRows(at: [indexPath], with: .automatic)
                self.delegate?.feedDetailView(self, tagsDidChange: self.tags)

                handler(true)
            }
        }

        let swipeActions = UISwipeActionsConfiguration(actions: [delete, edit])
        swipeActions.performsFirstActionWithFullSwipe = true
        return swipeActions
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let tag = self.tags[indexPath.row]

        self.delegate?.feedDetailView(self, editTag: tag) { newTag in
            self.tags[indexPath.row] = newTag
            tableView.reloadRows(at: [indexPath], with: .automatic)
            self.delegate?.feedDetailView(self, tagsDidChange: self.tags)
        }
    }
}
