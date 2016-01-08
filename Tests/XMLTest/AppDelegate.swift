//
//  AppDelegate.swift
//  XMLTest
//
//  Created by SeokWon Cheul on 2016. 1. 8..
//
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window : UIWindow?
    var viewController : ViewController?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool
    {

        let URL = NSURL(string:"http://www.ibiblio.org/xml/examples/shakespeare/all_well.xml")
        var xmlString:NSString
        do {
            try xmlString = NSString(contentsOfURL:URL!, encoding:NSUTF8StringEncoding)
            print(" string : \(xmlString) ")
            
            let xmlDoc = NSDictionary.dictionaryWithXMLString(xmlString)
            print("dictionary: \(xmlDoc)")

        } catch {
            
        }
        
        self.window = UIWindow(frame:UIScreen.mainScreen().bounds)
        self.viewController = ViewController(nibName:"ViewController", bundle:nil)
        self.window!.rootViewController = self.viewController!
        self.window!.makeKeyAndVisible()
        return true
    }
}
