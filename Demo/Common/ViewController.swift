//
//  ViewController.swift
//  OAuthSwift
//
//  Created by Dongri Jin on 6/21/14.
//  Copyright (c) 2014 Dongri Jin. All rights reserved.
//

import OAuthSwift

#if os(iOS)
    import UIKit
    import SafariServices
#elseif os(OSX)
    import AppKit
#endif

class ViewController: OAuthViewController {
    // oauth swift object (retain)
    var oauthswift: OAuthSwift?
    
    var currentParameters = [String: String]()
    let formData = Semaphore<FormViewControllerData>()

    lazy var internalWebViewController: WebViewController = {
        let controller = WebViewController()
        #if os(OSX)
            controller.view = NSView(frame: NSRect(x:0, y:0, width: 450, height: 500)) // needed if no nib or not loaded from storyboard
        #elseif os(iOS)
            controller.view = UIView(frame: UIScreen.main.bounds) // needed if no nib or not loaded from storyboard
        #endif
        controller.delegate = self
        controller.viewDidLoad() // allow WebViewController to use this ViewController as parent to be presented
        return controller
    }()
    
}

extension ViewController: OAuthWebViewControllerDelegate {
    #if os(iOS) || os(tvOS)
    
    func oauthWebViewControllerDidPresent() {
        
    }
    func oauthWebViewControllerDidDismiss() {
        
    }
    #endif
    
    func oauthWebViewControllerWillAppear() {
        
    }
    func oauthWebViewControllerDidAppear() {
        
    }
    func oauthWebViewControllerWillDisappear() {
        
    }
    func oauthWebViewControllerDidDisappear() {
        // Ensure all listeners are removed if presented web view close
        oauthswift?.cancel()
    }
}

extension ViewController {
    
    // MARK: - do authentification
    func doAuthService(service: String) {
        
        // Check parameters
        guard var parameters = services[service] else {
            showAlertView(title: "Miss configuration", message: "\(service) not configured")
            return
        }
        self.currentParameters = parameters
        
        // Ask to user by showing form from storyboards
        self.formData.data = nil
        Queue.main.async { [unowned self] in
            self.performSegue(withIdentifier: Storyboards.Main.FormSegue, sender: self)
            // see prepare for segue
        }
        // Wait for result
        guard let data = formData.waitData() else {
            // Cancel
            return
        }

        parameters["consumerKey"] = data.key
        parameters["consumerSecret"] = data.secret
        
        if Services.parametersEmpty(parameters) { // no value to set
            let message = "\(service) seems to have not weel configured. \nPlease fill consumer key and secret into configuration file \(self.confPath)"
            print(message)
            Queue.main.async { [unowned self] in
                self.showAlertView(title: "Key and secret must not be empty", message: message)
            }
        }

        parameters["name"] = service

        switch service {
        case "netiq" :
            doOAuthNetIQ(parameters)
                default:
            print("\(service) not implemented")
        }
    }
    
    // MARK: Spotify
    func doOAuthNetIQ(_ serviceParameters: [String:String]){
        let oauthswift = OAuth2Swift(
            consumerKey:    "464239f0-cd87-406f-9fef-4c5aed68c834",
            consumerSecret: "L-5Z51jzE9Hc_1P5FH6U93PwLjk3MW-jxG5p1ywvNfjsSDIOoGsF6qsyYA7-vEPbC7rssCmx7Y57P0kn6VU9wg",
            authorizeUrl:   "https://tri-netnam-poc.twiuat.dom/nidp/oauth/nam/authz",
            accessTokenUrl: "https://tri-netnam-poc.twiuat.dom/nidp/oauth/nam/token",
            responseType:   "code"
        )
        self.oauthswift = oauthswift
        oauthswift.authorizeURLHandler = getURLHandler()
        let state = generateState(withLength: 20)
        
        let _ = oauthswift.authorize(
            withCallbackURL: URL(string: "oauth-swift://oauth-callback/netiq")!,
            scope: "user-library-modify",
            state: state,
            success: { credential, response, parameters in
                self.showTokenAlert(name: serviceParameters["name"], credential: credential)
        },
            failure: { error in
                print(error.description)
        }
        )
    }
}

let services = Services()
let DocumentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
let FileManager: FileManager = Foundation.FileManager.default

extension ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load config from files
        initConf()
        
        // init now web view handler
        let _ = internalWebViewController.webView
        
        #if os(iOS)
            self.navigationItem.title = "OAuth"
            let tableView: UITableView = UITableView(frame: self.view.bounds, style: .plain)
            tableView.delegate = self
            tableView.dataSource = self
            self.view.addSubview(tableView)
        #endif
    }
    
    // MARK: utility methods
    
    var confPath: String {
        let appPath = "\(DocumentDirectory)/.oauth/"
        if !FileManager.fileExists(atPath: appPath) {
            do {
                try FileManager.createDirectory(atPath: appPath, withIntermediateDirectories: false, attributes: nil)
            }catch {
                print("Failed to create \(appPath)")
            }
        }
        return "\(appPath)Services.plist"
    }
    
    func initConf() {
        print("Load configuration from \n\(self.confPath)")
        
        // Load config from model file
        if let path = Bundle.main.path(forResource: "Services", ofType: "plist") {
            services.loadFromFile(path)
            
            if !FileManager.fileExists(atPath: confPath) {
                do {
                    try FileManager.copyItem(atPath: path, toPath: confPath)
                }catch {
                    print("Failed to copy empty conf to\(confPath)")
                }
            }
        }
        services.loadFromFile(confPath)
    }
    
    func snapshot() -> Data {
        #if os(iOS)
            UIGraphicsBeginImageContext(self.view.frame.size)
            self.view.layer.render(in: UIGraphicsGetCurrentContext()!)
            let fullScreenshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            UIImageWriteToSavedPhotosAlbum(fullScreenshot!, nil, nil, nil)
            return UIImageJPEGRepresentation(fullScreenshot!, 0.5)!
        #elseif os(OSX)
            let rep: NSBitmapImageRep = self.view.bitmapImageRepForCachingDisplay(in: self.view.bounds)!
            self.view.cacheDisplay(in: self.view.bounds, to:rep)
            return rep.tiffRepresentation!
        #endif
    }
    
    func showAlertView(title: String, message: String) {
        #if os(iOS)
            let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        #elseif os(OSX)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "Close")
            alert.runModal()
        #endif
    }
    
    func showTokenAlert(name: String?, credential: OAuthSwiftCredential) {
        var message = "oauth_token:\(credential.oauthToken)"
        if !credential.oauthTokenSecret.isEmpty {
            message += "\n\noauth_token_secret:\(credential.oauthTokenSecret)"
        }
        self.showAlertView(title: name ?? "Service", message: message)
        
        if let service = name {
            services.updateService(service, dico: ["authentified":"1"])
            // TODO refresh graphic
        }
    }
    
    // MARK: handler
    
    func getURLHandler() -> OAuthSwiftURLHandlerType {
        guard let type = self.formData.data?.handlerType else {
            return OAuthSwiftOpenURLExternally.sharedInstance
        }
        switch type {
        case .external :
            return OAuthSwiftOpenURLExternally.sharedInstance
        case .`internal`:
            if internalWebViewController.parent == nil {
                self.addChildViewController(internalWebViewController)
            }
            return internalWebViewController
        case .safari:
            #if os(iOS)
                if #available(iOS 9.0, *) {
                    let handler = SafariURLHandler(viewController: self, oauthSwift: self.oauthswift!)
                    handler.presentCompletion = {
                        print("Safari presented")
                    }
                    handler.dismissCompletion = {
                        print("Safari dismissed")
                    }
                    handler.factory = { url in
                        let controller = SFSafariViewController(url: url)
                        // Customize it, for instance
                        if #available(iOS 10.0, *) {
                           //  controller.preferredBarTintColor = UIColor.red
                        }
                        return controller
                    }
                    
                    return handler
                }
            #endif
            return OAuthSwiftOpenURLExternally.sharedInstance
        }
        
        #if os(OSX)
            // a better way is
            // - to make this ViewController implement OAuthSwiftURLHandlerType and assigned in oauthswift object
            /* return self */
            // - have an instance of WebViewController here (I) or a segue name to launch (S)
            // - in handle(url)
            //    (I) : affect url to WebViewController, and  self.presentViewControllerAsModalWindow(self.webViewController)
            //    (S) : affect url to a temp variable (ex: urlForWebView), then perform segue
            /* performSegueWithIdentifier("oauthwebview", sender:nil) */
            //         then override prepareForSegue() to affect url to destination controller WebViewController
            
        #endif
    }
    //(I)
    //let webViewController: WebViewController = internalWebViewController
    //(S)
    //var urlForWebView:?URL = nil
    
    
    override func prepare(for segue: OAuthStoryboardSegue, sender: Any?) {
        if segue.identifier == Storyboards.Main.FormSegue {
            #if os(OSX)
                let controller = segue.destinationController as? FormViewController
            #else
                let controller = segue.destination as? FormViewController
            #endif
            // Fill the controller
            if let controller = controller {
                controller.delegate = self
            }
        }
        
        super.prepare(for: segue, sender: sender)
    }
    
}

public typealias Queue = DispatchQueue
// MARK: - Table

#if os(iOS)
    extension ViewController: UITableViewDelegate, UITableViewDataSource {
        // MARK: UITableViewDataSource
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return services.keys.count
        }
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: "Cell")
            let service = services.keys[indexPath.row]
            cell.textLabel?.text = service
            
            if let parameters = services[service] , Services.parametersEmpty(parameters) {
                cell.textLabel?.textColor = UIColor.red
            }
            if let parameters = services[service], let authentified = parameters["authentified"], authentified == "1" {
                cell.textLabel?.textColor = UIColor.green
            }
            return cell
        }
        
        // MARK: UITableViewDelegate
          func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let service: String = services.keys[indexPath.row]
            
            DispatchQueue.global(qos: .background).async {
                self.doAuthService(service: service)
            }
            tableView.deselectRow(at: indexPath, animated:true)
        }
    }
#elseif os(OSX)
    extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
        // MARK: NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return services.keys.count
        }
        
        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            return services.keys[row]
        }
        
        // MARK: NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
            let service = services.keys[row]
            if let parameters = services[service], Services.parametersEmpty(parameters) {
                rowView.backgroundColor = NSColor.red
            }
            if let parameters = services[service], let authentified = parameters["authentified"], authentified == "1" {
                rowView.backgroundColor  = NSColor.green
            }
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            if let tableView = notification.object as? NSTableView {
                let row = tableView.selectedRow
                if  row != -1 {
                    let service: String = services.keys[row]
                    
                    
                    DispatchQueue.global(qos: .background).async {
                        self.doAuthService(service: service)
                    }
                    tableView.deselectRow(row)
                }
            }
        }
    }
#endif

struct FormViewControllerData {
    var key: String
    var secret: String
    var handlerType: URLHandlerType
}

extension ViewController: FormViewControllerDelegate {
    
    var key: String? { return self.currentParameters["consumerKey"] }
    var secret: String? {return self.currentParameters["consumerSecret"] }
    
    func didValidate(key: String?, secret: String?, handlerType: URLHandlerType) {
        self.dismissForm()
        
        self.formData.publish(data: FormViewControllerData(key: key ?? "", secret: secret ?? "", handlerType: handlerType))
    }
    
    func didCancel() {
        self.dismissForm()
        
        self.formData.cancel()
    }
    
    func dismissForm() {
        #if os(iOS)
            /*self.dismissViewControllerAnimated(true) { // without animation controller
             print("form dismissed")
             }*/
            let _ = self.navigationController?.popViewController(animated: true)
        #endif
    }
}

// Little utility class to wait on data
class Semaphore<T> {
    let segueSemaphore = DispatchSemaphore(value: 0)
    var data: T?
    
    func waitData(timeout: DispatchTime? = nil) -> T? {
        if let timeout = timeout {
            let _ = segueSemaphore.wait(timeout: timeout) // wait user
        } else {
            segueSemaphore.wait()
        }
        return data
    }
    
    func publish(data: T) {
        self.data = data
        segueSemaphore.signal()
    }
    
    func cancel() {
        segueSemaphore.signal()
    }
}
