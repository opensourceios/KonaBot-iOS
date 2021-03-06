//
//  CollectionViewController.swift
//  KonaBot
//
//  Created by Alex Ling on 31/10/2015.
//  Copyright © 2015 Alex Ling. All rights reserved.
//

import UIKit
import Kanna
import AFNetworking

class CollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, KonaAPIPostDelegate, KonaAPIErrorDelegate, KonaHTMLParserTagsDelegate {
	
	var refreshControl : UIRefreshControl!
	
	var searchVC : SearchViewController?
	var loading : SteamLoadingView!
	
	var r18 : Bool = false

	var keyword : String = ""

	var posts : [Post] = []
	var postSelectable : [Bool] = []
	var postsPerRequest : Int = 30
	
	var currentPage : Int = 1
	
	var compact : Bool = true
	
	var cellWidth : CGFloat!
	
	var columnNum : Int!
	
	var api : KonaAPI!
	
	var alert : AWAlertView?
	
	var isFromDetailTableVC = false
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		if NSUserDefaults.standardUserDefaults().objectForKey("tabToSelect") != nil {
			let tabToSelect = NSUserDefaults.standardUserDefaults().integerForKey("tabToSelect")
			NSUserDefaults.standardUserDefaults().removeObjectForKey("tabToSelect")
			self.tabBarController!.selectedIndex = tabToSelect
		}
		
		self.refreshControl = UIRefreshControl()
		self.refreshControl.addTarget(self, action: #selector(self.refresh), forControlEvents: .ValueChanged)
		self.refreshControl.tintColor = UIColor.konaColor()
		self.collectionView!.addSubview(self.refreshControl)
		
		self.refresh()
    }
	
	func refresh(){
		
		self.r18 = Yuno().baseUrl().containsString(".com")
		
		self.compact = NSUserDefaults.standardUserDefaults().integerForKey("viewMode") == 1
		
		if UIDevice.currentDevice().model.hasPrefix("iPad"){
			self.columnNum = 3
		}
		else{
			if CGSize.screenSize().width >= 375 && self.compact {
				self.columnNum = 2
			}
			else{
				self.columnNum = 1
			}
		}
		self.cellWidth = CGSize.screenSize().width/CGFloat(self.columnNum) - 5
		
		let layout : UICollectionViewFlowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
		layout.sectionInset = UIEdgeInsetsMake(0, (CGSize.screenSize().width/CGFloat(self.columnNum) - self.cellWidth)/2, 0, (CGSize.screenSize().width/CGFloat(self.columnNum) - self.cellWidth)/2)

		self.currentPage = 1
		self.posts = []
		self.collectionView!.reloadData()
		
		self.navigationItem.rightBarButtonItem = UIBarButtonItem()
		if self.r18 {
			let r18Label = UILabel(frame: CGRectMake(0, 0, 80, 20))
			r18Label.textColor = UIColor.konaColor()
			r18Label.text = "R18"
			r18Label.textAlignment = NSTextAlignment.Right
			self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: r18Label)
		}
		self.loading = SteamLoadingView(barNumber: nil, color: UIColor.konaColor(), minHeight: 10, maxHeight: 80, width: 20, spacing: 10, animationDuration: nil, deltaDuration: nil, delay: nil, options: nil)
		self.loading.alpha = 0.8
		self.view.addSubview(self.loading)
		
		if (self.keyword == ""){
			self.title = "Home".localized
		}
		else{
			self.title = self.keyword
		}
		self.api = KonaAPI(r18: self.r18, delegate: self, errorDelegate: self)
		self.loadMore()
		
		self.refreshControl.endRefreshing()
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return self.posts.count
    }
	
	override func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
		if indexPath.row == self.posts.count - (self.posts.count >= 4 ? 5 : 1) {
			self.loadMore()
		}
	}

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ImageCell", forIndexPath: indexPath) as! ImageCell
		
		if let img = Yuno().fetchImageWithKey("Preview", key: self.posts[indexPath.row].previewUrl) {
			cell.imageView.image = img
			self.postSelectable[indexPath.row] = true
		}
		else{
			cell.imageView.image = UIImage.imageWithColor(UIColor.placeHolderImageColor())
			downloadImg(self.posts[indexPath.row].previewUrl, view: cell.imageView, index: indexPath.row)
		}
		
        return cell
    }
	
	override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		if !self.postSelectable[indexPath.row] {return}
		let detailVC : DetailViewController = DetailViewController()
		detailVC.postUrl = self.posts[indexPath.row].postUrl
		detailVC.heightOverWidth = self.posts[indexPath.row].heightOverWidth
		detailVC.imageUrl = self.posts[indexPath.row].url
		detailVC.smallImage =  (self.collectionView!.cellForItemAtIndexPath(indexPath) as! ImageCell).imageView!.image
		detailVC.post = self.posts[indexPath.row]
		self.navigationController!.pushViewController(detailVC, animated: true)
	}
	
	override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
		self.collectionView!.reloadData()
	}

	func downloadImg(url : String, view : UIImageView, index : Int){
		
		let manager = AFHTTPSessionManager()
		manager.responseSerializer = AFImageResponseSerializer()
		manager.GET(url, parameters: nil, progress: nil, success: {(task, response) in
			UIView.transitionWithView(view, duration: 0.5, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: {
				view.image = response as? UIImage
				}, completion: {(finished) in
					self.postSelectable[index] = true
			})
			Yuno().saveImageWithKey("Preview", image: view.image!, key: url, skipUpload: false)
			}, failure: {(task, error) in
				print (error.localizedDescription)
				
				if let _alert = self.alert {
					if !_alert.alertHidden {
						return
					}
				}
				self.alert = AWAlertView.networkAlertFromError(error)
				self.navigationController?.view.addSubview(self.alert!)
				self.alert!.showAlert()
		})
	}
	
	func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {

		return CGSize(width: self.cellWidth, height: self.cellWidth * self.posts[indexPath.row].heightOverWidth)
	}
	
	func loadMore(){
		self.api.getPosts(self.postsPerRequest, page: self.currentPage, tag: self.keyword)
		if !NSUserDefaults.standardUserDefaults().boolForKey("feedbackFinished") {
			if NSUserDefaults.standardUserDefaults().integerForKey("viewCount") > Yuno.viewCountBeforeFeedback {
				NSUserDefaults.standardUserDefaults().setBool(true, forKey: "feedbackFinished")
				_ = FeedbackManager(parentVC: self, backgroundVC: self.tabBarController!, baseColor: UIColor.themeColor(), secondaryColor: UIColor.konaColor(), dismissButtonColor: UIColor.konaColor())
			}
		}
	}
	
	func konaAPIDidGetPost(ary: [Post]) {
		if ary.count == 0 && self.keyword != "" {
			self.handleEmtptySearch()
			return
		}
		if ary.count == 0 && self.keyword == "" {
			//when all posts in first fetch are R18
			self.currentPage += 1
			self.loadMore()
			return
		}
		self.currentPage += 1
		self.loading.removeFromSuperview()
		self.posts += ary
		self.postSelectable += [Bool](count: ary.count, repeatedValue: false)
		var index : [NSIndexPath] = []
		for i in self.collectionView!.numberOfItemsInSection(0) ..< self.posts.count {
			index.append(NSIndexPath(forRow: i, inSection: 0))
		}
		self.collectionView!.insertItemsAtIndexPaths(index)
	}
	
	func konaAPIGotError(error: NSError) {
		if let _alert = self.alert {
			if !_alert.alertHidden {
				return
			}
		}
		self.alert = AWAlertView.networkAlertFromError(error)
		self.navigationController?.view.addSubview(self.alert!)
		self.alert!.showAlert()
	}
	
	func konaHTMLParserFinishedParsing(tags: [String]) {
		if (self.searchVC != nil && self.posts.count == 0){
			if self.isFromDetailTableVC {
				self.alert = AWAlertView.redAlertFromTitleAndMessage("No Result Found".localized, message: "Post with this tag does not exist. Please try another tag".localized)
				self.navigationController!.view.addSubview(self.alert!)
				self.alert!.showAlert()
				self.navigationController!.popViewControllerAnimated(true)
				return
			}
			self.searchVC!.noResult = true
			if (tags.count > 0){
				self.searchVC!.suggestedTag = tags
			}
			self.navigationController!.popViewControllerAnimated(true)
		}
	}
	
	//Parse HTML and get suggested tags
	func handleEmtptySearch(){
		let konaParser = KonaHTMLParser(delegate: self, errorDelegate: self)
		konaParser.getSuggestedTagsFromEmptyTag(self.keyword.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())!)
	}
}
