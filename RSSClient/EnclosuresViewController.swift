//
//  EnclosuresViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 12/10/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class EnclosuresViewController: UIViewController {
    
    var enclosures : [Enclosure]? = nil {
        didSet {
            enclosuresView.enclosures = enclosures
        }
    }
    
    let enclosuresView = EnclosuresView(frame: CGRectZero)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("Enclosures", comment: "")
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        
        enclosuresView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(enclosuresView)
        enclosuresView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsMake(8, 8, 8, 8))
        
        enclosuresView.openEnclosure = {(enclosure) in
            let vc = UIViewController()
            let webView = UIWebView()
            
            vc.view.addSubview(webView)
            webView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
            webView.loadData(enclosure.data, MIMEType: enclosure.kind, textEncodingName: "UTF-8", baseURL: NSURL(string: enclosure.url))
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func dismiss() {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
}
