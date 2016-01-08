//
//  XMLDictionary.swift
//
//  Version 1.4
//
//  Created by Nick Lockwood on 15/11/2010.
//  Copyright 2010 Charcoal Design. All rights reserved.
//
//  Get the latest version of XMLDictionary from here:
//
//  https://github.com/nicklockwood/XMLDictionary
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.

import Foundation

enum XMLDictionaryAttributesMode {
    case XMLDictionaryAttributesModePrefixed //default
    case XMLDictionaryAttributesModeDictionary
    case XMLDictionaryAttributesModeUnprefixed
    case XMLDictionaryAttributesModeDiscard
}

enum XMLDictionaryNodeNameMode {
    case XMLDictionaryNodeNameModeRootOnly //default
    case XMLDictionaryNodeNameModeAlways
    case XMLDictionaryNodeNameModeNever
}

let XMLDictionaryAttributesKey  : NSString  = "__attributes"
let XMLDictionaryCommentsKey    : NSString  = "__comments"
let XMLDictionaryTextKey        : NSString  = "__text"
let XMLDictionaryNodeNameKey    : NSString  = "__name"
let XMLDictionaryAttributePrefix: NSString  = "_"

class XMLDictionaryParser : NSObject, NSCopying, NSXMLParserDelegate {
    
    var collapseTextNodes : Bool // defaults to YES
    var stripEmptyNodes : Bool   // defaults to YES
    var trimWhiteSpace : Bool    // defaults to YES
    var alwaysUseArrays : Bool   // defaults to NO
    var preserveComments : Bool  // defaults to NO
    var wrapRootNode : Bool      // defaults to NO
    
    var attributesMode : XMLDictionaryAttributesMode
    var nodeNameMode : XMLDictionaryNodeNameMode
    
    private var root : NSMutableDictionary?
    private var stack : NSMutableArray?
    private var text : NSMutableString?

    private static var once : dispatch_once_t = 0
    private static var _sharedInstance : XMLDictionaryParser?
    static var sharedInstance : XMLDictionaryParser {
        get {

            dispatch_once(&once) {
                self._sharedInstance = XMLDictionaryParser()
            }
            return self._sharedInstance!
        }
    }
    override init() {
        self.collapseTextNodes = true;
        self.stripEmptyNodes = true;
        self.trimWhiteSpace = true;
        self.alwaysUseArrays = false;
        self.preserveComments = false;
        self.wrapRootNode = false;
        self.attributesMode = .XMLDictionaryAttributesModePrefixed
        self.nodeNameMode = .XMLDictionaryNodeNameModeRootOnly
        super.init()
    }
    func copyWithZone(zone : NSZone) -> AnyObject {
        let copy = XMLDictionaryParser()
        copy.collapseTextNodes = self.collapseTextNodes;
        copy.stripEmptyNodes = self.stripEmptyNodes;
        copy.trimWhiteSpace = self.trimWhiteSpace;
        copy.alwaysUseArrays = self.alwaysUseArrays;
        copy.preserveComments = self.preserveComments;
        copy.attributesMode = self.attributesMode;
        copy.nodeNameMode = self.nodeNameMode;
        copy.wrapRootNode = self.wrapRootNode;
        return copy;
    }
    func dictionaryWithParser(parser : NSXMLParser) -> NSDictionary {
        parser.delegate = self
        parser.parse()
        let result : AnyObject = self.root!
        self.root = nil
        self.stack = nil
        return result as! NSDictionary
    }
    func dictionaryWithData(data : NSData) -> NSDictionary {
        let parser = NSXMLParser(data:data)
        return self.dictionaryWithParser(parser)
    }
    func dictionaryWithString(string : NSString) -> NSDictionary {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding)
        return self.dictionaryWithData(data!)
    }
    func dictionaryWithFile(path : NSString) -> NSDictionary {
        let data = NSData(contentsOfFile:path as String)
        return self.dictionaryWithData(data!)
    }
    
    class func XMLStringForNode(node : AnyObject, withNodeName nodeName:String ) -> String?
    {
        if node is NSArray
        {
            let nodes = NSMutableArray(capacity:node.count)
            for individualNode in (node as! NSArray)
            {
                nodes.addObject(self.XMLStringForNode(individualNode, withNodeName:nodeName)!)
            }
            return nodes.componentsJoinedByString("\n")
        }
        else if node is NSDictionary
        {
            let attributes = (node as! NSDictionary).attributes()
            let attributeString = NSMutableString()
            for key in attributes!.allKeys
            {
                
                attributeString.appendFormat(" %@=\"%@\"", key.description.XMLEncodedString(), attributes![key as! String]!.description.XMLEncodedString())
            }
            
            let innerXML = node.innerXML as! AnyObject as! NSString
            if innerXML.length > 0
            {
                return NSString(format:"<%1$@%2$@>%3$@</%1$@>", nodeName, attributeString, innerXML) as String
            }
            else
            {
                return NSString(format:"<%@%@/>", nodeName, attributeString) as String
            }
        }
        else
        {
            return NSString(format:"<%1$@>%2$@</%1$@>", nodeName, node.description.XMLEncodedString()) as String
        }
    }
    func endText() {
        if self.text == nil {
            return
        }
        if self.trimWhiteSpace == true
        {
            self.text = self.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).mutableCopy() as? NSMutableString
        }
        if self.text!.length > 0
        {
            let top = self.stack!.lastObject as! NSMutableDictionary
            let existing = top[XMLDictionaryTextKey]
            if existing is NSArray
            {
                existing!.addObject(self.text!)
            }
            else if existing != nil
            {
                top[XMLDictionaryTextKey] = [existing!, self.text!].mutableCopy()
            }
            else
            {
                top[XMLDictionaryTextKey] = self.text;
            }
        }
        self.text = nil;
    }
    func addText(text : NSString?)
    {
        if self.text == nil
        {
            self.text = NSMutableString(string:text!)
        }
        else
        {
            self.text!.appendString(text! as String)
        }
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String])

    {
        self.endText()
        
        let node = NSMutableDictionary()
        
        switch self.nodeNameMode
        {
            
        case .XMLDictionaryNodeNameModeRootOnly:
            if self.root == nil
            {
                node[XMLDictionaryNodeNameKey] = elementName;
            }
        case .XMLDictionaryNodeNameModeAlways:
            node[XMLDictionaryNodeNameKey] = elementName;
        case .XMLDictionaryNodeNameModeNever:
            break
        }
        
        if attributeDict.count > 0
        {
            switch self.attributesMode
            {
            case .XMLDictionaryAttributesModePrefixed:
                for key in (attributeDict as NSDictionary).allKeys
                {
                    node[XMLDictionaryAttributePrefix.stringByAppendingString(key as! String)] = attributeDict[key as! String]
                }
            case .XMLDictionaryAttributesModeDictionary:
                node[XMLDictionaryAttributesKey] = attributeDict;
            case .XMLDictionaryAttributesModeUnprefixed:
                node.addEntriesFromDictionary(attributeDict as [NSObject : AnyObject])
            case .XMLDictionaryAttributesModeDiscard:
                break
            }
        }
        
        if self.root == nil
        {
            self.root = node;
            self.stack = NSMutableArray(object:node)
            if self.wrapRootNode == true
            {
                self.root = NSMutableDictionary(object:self.root!, forKey:elementName)
                self.stack!.insertObject(self.root!, atIndex:0)
            }
        }
        else
        {
            let top = (self.stack!.lastObject) as! NSMutableDictionary
            let existing = top[elementName]
            if existing is NSArray
            {
                existing!.addObject(node)
            }
            else if existing != nil
            {
                top[elementName] = [existing!, node].mutableCopy()
            }
            else if self.alwaysUseArrays == true
            {
                top[elementName] = NSMutableArray(object:node)
            }
            else
            {
                top[elementName] = node;
            }
            self.stack!.addObject(node)
        }
    }
    func nameForNode(node : NSDictionary, inDictionary dict:NSDictionary) -> NSString?
    {
        if let nodeName = node.nodeName()
        {
            return nodeName
        }
        else
        {
            for element in dict
            {
                if (element.value === node)
                {
                    return (element.key as! NSString)
                }
                else if (element.value is NSArray) && element.value.containsObject(node)
                {
                    return (element.key as! NSString)
                }
            }
        }
        return nil
    }
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        
        self.endText()
        
        let top = self.stack!.lastObject as! NSMutableDictionary
        self.stack!.removeLastObject()
        
        if top.attributes() == nil && top.childNodes() == nil && top.comments() == nil
        {
            let newTop = self.stack!.lastObject as! NSMutableDictionary
            let nodeName = self.nameForNode(top, inDictionary:newTop)
            if nodeName != nil
            {
                let parentNode = newTop[nodeName!]
                if (top.innerText() != nil) && self.collapseTextNodes
                {
                    if parentNode is NSArray
                    {
                        (parentNode! as! NSMutableArray)[parentNode!.count - 1] = top.innerText()!
                    }
                    else
                    {
                        newTop[nodeName!] = top.innerText()
                    }
                }
                else if (top.innerText() == nil) && self.stripEmptyNodes
                {
                    if parentNode is NSArray
                    {
                        parentNode!.removeLastObject()
                    }
                    else
                    {
                        newTop.removeObjectForKey(nodeName!)
                    }
                }
                else if (top.innerText() == nil) && self.collapseTextNodes && self.stripEmptyNodes
                {
                    top[XMLDictionaryTextKey] = ""
                }
            }
        }
    }

    func parser(parser: NSXMLParser, foundCharacters string: String)
    {
        self.addText(string)
    }
    func parser(parser: NSXMLParser, foundCDATA CDATABlock: NSData)
    {
        self.addText(NSString(data: CDATABlock, encoding: NSUTF8StringEncoding))
    }
    func parser(parser: NSXMLParser, foundComment comment: String)
    {
        if self.preserveComments
        {
            let top = self.stack!.lastObject as! NSMutableDictionary
            var comments = top[XMLDictionaryCommentsKey] as? NSMutableArray
            if comments == nil
            {
                comments = ([comment].mutableCopy() as! NSMutableArray)
                top[XMLDictionaryCommentsKey] = comments;
            }
            else
            {
                comments!.addObject(comment)
            }
        }
    }

}
// MARK: NSDictionary extension for XMLDictionary
extension NSDictionary {
    
    class func dictionaryWithXMLParser(parser : NSXMLParser) -> NSDictionary
    {
        return XMLDictionaryParser.sharedInstance.copy().dictionaryWithParser(parser)
    }
    
    class func dictionaryWithXMLData(data : NSData) -> NSDictionary
    {
        return XMLDictionaryParser.sharedInstance.copy().dictionaryWithData(data)
    }
    
    class func dictionaryWithXMLString(string : NSString) -> NSDictionary
    {
        return XMLDictionaryParser.sharedInstance.copy().dictionaryWithString(string)
    }
    
    class func dictionaryWithXMLFile(path : NSString) -> NSDictionary
    {
        return XMLDictionaryParser.sharedInstance.copy().dictionaryWithFile(path)
    }
    
    func attributes() -> NSDictionary?
    {
        let attributes = self[XMLDictionaryAttributesKey] as? NSDictionary
        if attributes != nil
        {
            return attributes!.count > 0 ? attributes! : nil
        }
        else
        {
            let filteredDict = NSMutableDictionary(dictionary:self)
            filteredDict.removeObjectsForKeys([XMLDictionaryCommentsKey, XMLDictionaryTextKey, XMLDictionaryNodeNameKey])
            for key in filteredDict.allKeys
            {
                let keyString = key as! NSString
                filteredDict.removeObjectForKey(key)
                if keyString.hasPrefix(XMLDictionaryAttributePrefix as String)
                {
                    
                    let filterKey = keyString.substringFromIndex(XMLDictionaryAttributePrefix.length)
                    filteredDict[filterKey] = self[filterKey]
                }
            }
            return filteredDict.count > 0 ? filteredDict : nil
        }
    }
    
    func childNodes() -> NSDictionary?
    {
        let filteredDict = self.mutableCopy() as? NSMutableDictionary
        filteredDict!.removeObjectsForKeys([XMLDictionaryAttributesKey, XMLDictionaryCommentsKey, XMLDictionaryTextKey, XMLDictionaryNodeNameKey])
        for key in filteredDict!.allKeys
        {
            if key.hasPrefix(XMLDictionaryAttributePrefix as String)
            {
                filteredDict!.removeObjectForKey(key)
            }
        }
        return filteredDict!.count > 0 ? filteredDict : nil
    }
    func comments() -> NSArray?
    {
        return self[XMLDictionaryCommentsKey] as? NSArray
    }
    
    func nodeName() -> NSString?
    {
        return self[XMLDictionaryNodeNameKey] as? NSString
    }
    
    func innerText() -> AnyObject?
    {
        let text = self[XMLDictionaryTextKey as String]
        if text is NSArray
        {
            return text!.componentsJoinedByString("\n")
        }
        else
        {
            return text
        }
    }
    
    func innerXML() -> NSString
    {
        let nodes = NSMutableArray()
        
        for comment in self.comments()!
        {
            nodes.addObject(NSString(format:"<!--%@-->", comment.XMLEncodedString()))
        }
        
        let childNodes = self.childNodes()
        for key in childNodes!
        {
            let keyString = key as! AnyObject as! String
            nodes.addObject(XMLDictionaryParser.XMLStringForNode(childNodes![keyString]!, withNodeName:keyString)!)
        }
        
        let text = self.innerText() as? NSString
        if text != nil
        {
            nodes.addObject(text!.XMLEncodedString())
        }
        
        return nodes.componentsJoinedByString("\n")
    }
    func XMLString() -> NSString? {
        if self.count == 1 && self.nodeName() == nil
        {
            //ignore outermost dictionary
            return self.innerXML()
        }
        else
        {
            let nodeName = self.nodeName() != nil ? self.nodeName() : "root"
            return XMLDictionaryParser.XMLStringForNode(self, withNodeName:nodeName! as String)
        }
    }
    func arrayValueForKeyPath(keyPath : NSString) -> NSArray?
    {
        let value = self.valueForKeyPath(keyPath as String)
        if (value != nil) && (value is NSArray == false)
        {
            return [value!]
        }
        return value as? NSArray
    }
    func stringValueForKeyPath(keyPath : NSString) -> NSString?
    {
        var value = self.valueForKeyPath(keyPath as String)
        if value is NSArray
        {
            value = value!.count > 0 ? value![0] : nil;
        }
        if value is NSDictionary
        {
            return (value as! NSDictionary).innerText() as? NSString
        }
        return value as? NSString
    }
    
    func dictionaryValueForKeyPath(keyPath : NSString) -> NSDictionary?
    {
        var value = self.valueForKeyPath(keyPath as String)
        if value is NSArray
        {
            value = value!.count > 0 ? value![0] : nil
        }
        if value is NSString
        {
            return [XMLDictionaryTextKey : value!]
        }
        return value as? NSDictionary
    }
}
// MARK: NSString extension for XMLDictionary
extension NSString {
    func XMLEncodedString() -> NSString
    {
        return self.stringByReplacingOccurrencesOfString("&", withString:"&amp;").stringByReplacingOccurrencesOfString("<", withString:"&lt;").stringByReplacingOccurrencesOfString(">", withString:"&gt;").stringByReplacingOccurrencesOfString("\"", withString:"&quot;").stringByReplacingOccurrencesOfString("\'", withString:"&apos;")
    }
    
}
