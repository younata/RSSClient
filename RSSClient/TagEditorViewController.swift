//
//  TagEditorViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/2/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class TagEditorViewController: UIViewController {
    
    var feed : Feed? = nil
    var tag: String? = nil {
        didSet {
            self.navigationItem.rightBarButtonItem?.enabled = self.feed != nil && tag != nil
        }
    }
    
    var tagIndex : Int? = nil
    
    let tagLabel = UILabel(forAutoLayout: ())
    
    let tagPicker = TagPickerView(frame: CGRectZero)
    
    var dataManager: DataManager? = nil {
        didSet {
            if let dm = dataManager {
                tagPicker.allTags = dm.allTags()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.title = self.feed?.feedTitle() ?? ""
        
        tagPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(tagPicker)
        tagPicker.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(16, 8, 0, 8), excludingEdge: .Bottom)
        tagPicker.didSelect = {
            self.tag = $0
        }
        
        self.view.addSubview(tagLabel)
        tagLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(0, 8, 8, 8), excludingEdge: .Top)
        tagLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: tagPicker, withOffset: 8)
        tagLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        tagLabel.text = NSLocalizedString("Tags:", comment: "")
        tagLabel.text! += "\n"
        tagLabel.text! += NSLocalizedString("Prefixing a tag with '~' will set the title to that, minus the leading ~. Prefixing a tag with '`' will set the summary to that, minus the leading `. Tags cannot contain commas (,)", comment: "")
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        if let feed = self.feed {
            var tags = feed.allTags()
            if let ti = tagIndex {
                tags[ti] = tag!
            } else {
                tags.append(tag!)
            }
            feed.tags = tags
        }
        
        self.dismiss()
    }
}