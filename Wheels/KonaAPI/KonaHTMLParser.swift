//
//  KonaHTMLParser.swift
//  KonaBot
//
//  Created by Alex Ling on 11/1/2016.
//  Copyright © 2016 Alex Ling. All rights reserved.
//

import UIKit
import Kanna
import AFNetworking

protocol KonaHTMLParserDelegate {
	func konaHTMLParserFinishedParsing(parsedPost : ParsedPost)
}

protocol KonaHTMLParserTagsDelegate {
	func konaHTMLParserFinishedParsing(tags : [String])
}

//Some data such as comments of a post can not be accessed using API, so I have to parse the HTML and get the information I need
class KonaHTMLParser: NSObject {
	
	private var delegate : KonaHTMLParserDelegate!
	private var tagDelegate : KonaHTMLParserTagsDelegate!
	private var errorDelegate : KonaAPIErrorDelegate!
	private var parsedPost : ParsedPost!
	
	init(delegate : KonaHTMLParserDelegate, errorDelegate : KonaAPIErrorDelegate){
		self.delegate = delegate
		self.errorDelegate = errorDelegate
	}
	
	init(delegate : KonaHTMLParserTagsDelegate, errorDelegate : KonaAPIErrorDelegate){
		self.tagDelegate = delegate
		self.errorDelegate = errorDelegate
	}
	
	func getPostInformation (postUrl : String) {
		let successBlock : ((html : String) -> Void) = {(html) in
			self.parseHTML(html)
		}
		self.getHTML(postUrl, successBlock: successBlock)
	}
	
	private func getHTML (url : String, successBlock : ((html : String) -> Void)) {
		let manager = AFHTTPSessionManager()
		manager.responseSerializer = AFHTTPResponseSerializer()
		manager.GET(url, parameters: nil, progress: nil,
			success: {(task, response) in
				let html = NSString(data: response as! NSData, encoding: NSASCIIStringEncoding)! as String
				successBlock(html: html)
			}, failure: {(operation, error) -> Void in
				self.errorDelegate.konaAPIGotError(error)
				print ("Error : \(error)")
		})
	}
	
	private func parseHTML (html : String) {
		let doc = Kanna.HTML(html: html, encoding: NSUTF8StringEncoding)!
		
		var imageUrl = ""
		var tags : [String] = []
		var time : Int = 0
		var author : String = ""
		var rating : String = ""
		var score : String = ""
		
		let divAry = doc.at_css("body")?.at_css("div#content")?.at_css("div#post-view")?.at_css("div#right-col.content")?.css("div")
		for div in divAry! {
			if let img = div.at_css("img#image.image") {
				imageUrl = img["src"]!
			}
		}
		let sideBar = doc.at_css("body")?.at_css("div#content")?.at_css("div#post-view")?.at_css("div.sidebar")
		let divs = sideBar!.css("div")
		for div in divs {
			if let sideBar = div.at_css("ul#tag-sidebar") {
				let tagUl = sideBar.css("li")
				for tagLi in tagUl {
					let tag = tagLi.css("a").last!.text!.stringByReplacingOccurrencesOfString(" ", withString: "_")
					tags.append(tag)
				}
				break
			}
		}
		let stats = sideBar?.at_css("div#stats.vote-container")!
		let lis = stats!.at_css("ul")!.css("li")
		
		time = lis[1].at_css("a")!["title"]!.konaChanTimeToUnixTime()
		author = lis[1].css("a").count > 1 ? lis[1].css("a")[1].text! : "Unknown"
		rating = lis[4].text!.componentsSeparatedByString(" ")[1].localized
		score = lis[5].at_css("span")!.text!
		
		if !Yuno.r18 {
			tags = KonaAPI.r18Filter(tags)
		}
		
		self.parsedPost = ParsedPost(url: imageUrl, tags: tags, time: time, author: author, score: score, rating: rating)
		self.delegate.konaHTMLParserFinishedParsing(self.parsedPost)
	}
	
	private func parseSuggestedTagsFromHTML (html : String) -> [String] {
		var suggestedTag : [String] = []
		if let doc = Kanna.HTML(html: html, encoding: NSUTF8StringEncoding) {
			let ulList = doc.css("ul#post-list-posts")
			if ulList.count == 0 {
				for div in doc.css("div"){
					if (div.className != nil) {
						if (div.className! == "status-notice"){
							for span in div.css("span"){
								let a = span.at_css("a")!
								suggestedTag.append(a.text!)
							}
						}
					}
				}
			}
		}
		if !Yuno.r18 {
			suggestedTag = KonaAPI.r18Filter(suggestedTag)
		}
		return suggestedTag
	}
	
	func getSuggestedTagsFromEmptyTag (tag : String) {
		let successBlock = {(html : String) in
			let tags = self.parseSuggestedTagsFromHTML(html)
			self.tagDelegate.konaHTMLParserFinishedParsing(tags)
		}
		self.getHTML("\(Yuno().baseUrl())/post?tags=\(tag)", successBlock: successBlock)
	}
}

extension String {
	func konaChanTimeToUnixTime() -> Int {
		var ary = self.componentsSeparatedByString(" ")
		ary = ary.filter({element in
			element != ""
		})
		let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		
		let year : Int = (ary.last! as NSString).integerValue
		let month : Int = months.indexOf(ary[1])! + 1
		let day : Int = (ary[2] as NSString).integerValue
		let timeAry = ary[3].componentsSeparatedByString(":")
		let hour = (timeAry[0] as NSString).integerValue
		let minute = (timeAry[1] as NSString).integerValue
		let second = (timeAry[2] as NSString).integerValue
		
		let component = NSDateComponents()
		component.setValue(year, forComponent: .Year)
		component.setValue(month, forComponent: .Month)
		component.setValue(day, forComponent: .Day)
		component.setValue(hour, forComponent: .Hour)
		component.setValue(minute, forComponent: .Minute)
		component.setValue(second, forComponent: .Second)
		
		component.calendar = NSCalendar.currentCalendar()
		component.calendar!.timeZone = NSTimeZone(forSecondsFromGMT: 0)
		
		return Int(component.date!.timeIntervalSince1970)
	}
}
