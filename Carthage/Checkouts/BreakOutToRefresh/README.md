# BreakOutToRefresh
Play BreakOut while loading - A playable pull to refresh view using SpriteKit

![](https://raw.githubusercontent.com/dasdom/BreakOutToRefresh/master/PullToRefreshDemo/what.gif)

BreakOutToRefresh uses SpriteKit to add a playable mini game to the pull to refresh view in a table view. In this case the mini game is BreakOut but a lot of other mini games could be presented in this space.

## Swift 1.2

The code is updated for Swift 1.2. If you like to use it with Xcode 6.1.1 and Swift 1.1 checkout the tag Swift1_1.

## Installation

Add **BreakOutToRefreshView.swift** to your project.

## Usage

Add this to your table view controller:
```swift
var refreshView: BreakOutToRefreshView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let refreshHeight = CGFloat(100)
    refreshView = BreakOutToRefreshView(scrollView: tableView)
    refreshView.delegate = self
    
    // configure the colors of the refresh view
    refreshView.scenebackgroundColor = UIColor(hue: 0.68, saturation: 0.9, brightness: 0.3, alpha: 1.0)
    refreshView.paddleColor = UIColor.lightGrayColor()
    refreshView.ballColor = UIColor.whiteColor()
    refreshView.blockColors = [UIColor(hue: 0.17, saturation: 0.9, brightness: 1.0, alpha: 1.0), UIColor(hue: 0.17, saturation: 0.7, brightness: 1.0, alpha: 1.0), UIColor(hue: 0.17, saturation: 0.5, brightness: 1.0, alpha: 1.0)]
    
    tableView.addSubview(refreshView)
    
  }
  
extension DemoTableViewController: UIScrollViewDelegate {
 
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
    // load stuff from the internet
  }

}
```

When the loading of new content is finished, call `endRefreshing()` of the `refreshView`.

When `endRefreshing()` is called the mini game doesn't stop immediately. The game stops (and the view is dismissed) when the user lifts the finger. If you like to end the mini game immediately set the `forceEnd` property to true.

## Status

It's kind of beta status.

## To do

- Add scoring
- Add ending of the game when the ball hits the right wall
- Add levels

## Feedback

If you use this code or got inspired by the idea and build an app with a even more awesome PullToRefresh game, please let me know.

## Author

Dominik Hauser

[App.net: @dasdom](https://alpha.app.net/dasdom)

[Twitter: @dasdom](https://twitter.com/dasdom)

[swiftandpainless.com](http://swiftandpainless.com)

## Thanks

Thanks to [Ben Oztalay](https://github.com/boztalay/BOZPongRefreshControl) and [raywenderlich.com](http://www.raywenderlich.com) for inspiration.

## Licence

MIT
