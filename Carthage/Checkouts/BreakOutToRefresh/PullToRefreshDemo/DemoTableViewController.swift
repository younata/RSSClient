//
//  DemoTableViewController.swift
//  PullToRefreshDemo
//
//  Created by dasdom on 17.01.15.
//  Copyright (c) 2015 Dominik Hauser. All rights reserved.
//

import UIKit

class DemoTableViewController: UITableViewController {
  
  var refreshView: BreakOutToRefreshView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
//    let refreshHeight = CGFloat(100)
    refreshView = BreakOutToRefreshView(scrollView: tableView)
    refreshView.delegate = self
    
    // configure the refresh view
//    refreshView.scenebackgroundColor = UIColor(hue: 0.68, saturation: 0.9, brightness: 0.3, alpha: 1.0)
//    refreshView.textColor = UIColor.whiteColor()
//    refreshView.paddleColor = UIColor.lightGrayColor()
//    refreshView.ballColor = UIColor.whiteColor()
//    refreshView.blockColors = [UIColor(hue: 0.17, saturation: 0.9, brightness: 1.0, alpha: 1.0), UIColor(hue: 0.17, saturation: 0.7, brightness: 1.0, alpha: 1.0), UIColor(hue: 0.17, saturation: 0.5, brightness: 1.0, alpha: 1.0)]

    tableView.addSubview(refreshView)
    
  }

  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    refreshView.frame = CGRect(x: 0, y: -100, width: size.width, height: 100)
  }
  
  // MARK: - Table view data source
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 20
  }
  
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("DemoCell", forIndexPath: indexPath)
    
    cell.textLabel?.text = "Row \(indexPath.row)"
    
    return cell
  }
}

extension DemoTableViewController {
 
  override func scrollViewDidScroll(scrollView: UIScrollView) {
    refreshView.scrollViewDidScroll(scrollView)
  }
  
  override func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    refreshView.scrollViewWillEndDragging(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
  }
  
  override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
    refreshView.scrollViewWillBeginDragging(scrollView)
  }
}

extension DemoTableViewController: BreakOutToRefreshDelegate {
  
  func refreshViewDidRefresh(refreshView: BreakOutToRefreshView) {
    // this code is to simulage the loading from the internet
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC * 3)), dispatch_get_main_queue(), { () -> Void in
      refreshView.endRefreshing()
    })
  }

}
