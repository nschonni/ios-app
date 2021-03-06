//
//  AppDelegate.swift
//  IVPN Client
//
//  Created by Fedir Nepyyvoda on 9/29/16.
//  Copyright © 2016 IVPN. All rights reserved.
//

import UIKit
import Sentry

@UIApplicationMain

class AppDelegate: UIResponder {
    
    // MARK: - Properties -
    
    var window: UIWindow?
    
    // MARK: - Methods -
    
    private func setRootViewController() {
        if let window = window {
            window.rootViewController = NavigationManager.getMainViewController()
        }
    }
    
    private func evaluateFirstRun() {
        if UserDefaults.standard.object(forKey: "FirstInstall") == nil {
            KeyChain.clearAll()
            UserDefaults.clearSession()
            UserDefaults.standard.set(false, forKey: "FirstInstall")
            UserDefaults.standard.synchronize()
        }
    }
    
    func setupCrashReports() {
        guard UserDefaults.shared.isLoggingCrashes else { return }
        
        do {
            Client.shared = try Client(dsn: "https://\(Config.SentryDsn)")
            Client.shared?.enabled = true
            Client.shared?.beforeSerializeEvent = { event in
                event.environment = Config.Environment
            }
            try Client.shared?.startCrashHandler()
            log(info: "Sentry crash handler started successfully")
        } catch let error {
            log(error: "\(error)")
        }
    }
    
    private func loadServerList() {
        ApiService.shared.getServersList(storeInCache: true) { result in
            switch result {
            case .success(let serverList):
                Application.shared.serverList = serverList
            default:
                break
            }
        }
    }
    
    private func evaluateUITests() {
        // When running the application for UI Testing we need to remove all the stored data so we can start testing the clear app
        // It is impossible to access the KeyChain from the UI test itself as the test runs in different process
        
        if ProcessInfo.processInfo.arguments.contains("-UITests") {
            Application.shared.authentication.removeStoredCredentials()
            Application.shared.serviceStatus.isActive = false
            KeyChain.sessionToken = nil
            UserDefaults.clearSession()
            UserDefaults.shared.removeObject(forKey: UserDefaults.Key.hasUserConsent)
            UserDefaults.standard.set(true, forKey: "-UITests")
        }
        
        if ProcessInfo.processInfo.arguments.contains("-authenticated") {
            KeyChain.sessionToken = "token"
        }
        
        if ProcessInfo.processInfo.arguments.contains("-activeService") {
            Application.shared.serviceStatus.isActive = true
        }
        
        if ProcessInfo.processInfo.arguments.contains("-hasUserConsent") {
            UserDefaults.shared.set(true, forKey: UserDefaults.Key.hasUserConsent)
        }
    }
    
    private func registerUserDefaults() {
        UserDefaults.registerUserDefaults()
    }
    
    private func createLogFiles() {
        FileSystemManager.createLogFiles()
    }
    
    private func finishIncompletePurchases() {
        guard Application.shared.authentication.isLoggedIn || Application.shared.authentication.hasSignupCredentials else { return }
        
        IAPManager.shared.finishIncompletePurchases { serviceStatus, error in
            guard let viewController = UIApplication.topViewController() else { return }
            
            if let error = error {
                viewController.showErrorAlert(title: "Error", message: error.message)
            }

            if let serviceStatus = serviceStatus {
                viewController.showSubscriptionActivatedAlert(serviceStatus: serviceStatus)
            }
        }
    }
    
    private func resetLastPingTimestamp() {
        UserDefaults.shared.set(0, forKey: "LastPingTimestamp")
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let endpoint = url.host else {
            return false
        }
        
        switch endpoint {
        case Config.urlTypeConnect:
            DispatchQueue.delay(0.75, closure: {
                if UserDefaults.shared.networkProtectionEnabled {
                    Application.shared.connectionManager.resetRulesAndConnectShortcut(closeApp: true)
                    return
                }
                Application.shared.connectionManager.connectShortcut(closeApp: true)
            })
        case Config.urlTypeDisconnect:
            DispatchQueue.delay(0.75, closure: {
                if UserDefaults.shared.networkProtectionEnabled {
                    Application.shared.connectionManager.resetRulesAndDisconnectShortcut(closeApp: true)
                    return
                }
                Application.shared.connectionManager.disconnectShortcut(closeApp: true)
            })
        case Config.urlTypeLogin:
            if let topViewController = UIApplication.topViewController() {
                if #available(iOS 13.0, *) {
                    topViewController.present(NavigationManager.getLoginViewController(modalPresentationStyle: .automatic), animated: true, completion: nil)
                } else {
                    topViewController.present(NavigationManager.getLoginViewController(), animated: true, completion: nil)
                }
            }
        default:
            break
        }
        
        return true
    }

}

// MARK: - UIApplicationDelegate -

extension AppDelegate: UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupCrashReports()
        evaluateUITests()
        evaluateFirstRun()
        registerUserDefaults()
        setRootViewController()
        finishIncompletePurchases()
        createLogFiles()
        resetLastPingTimestamp()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let mainViewController = UIApplication.topViewController() as? MainViewController {
            mainViewController.refreshServiceStatus()
        }
        
        if UserDefaults.shared.networkProtectionEnabled {
            NetworkManager.shared.startMonitoring()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        NetworkManager.shared.stopMonitoring()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard Application.shared.authentication.isLoggedIn, Application.shared.serviceStatus.isActive else { return }
        
        switch shortcutItem.type {
        case "Connect":
            if UserDefaults.shared.networkProtectionEnabled {
                Application.shared.connectionManager.resetRulesAndConnectShortcut(closeApp: true)
                completionHandler(true)
                break
            }
            Application.shared.connectionManager.connectShortcut(closeApp: true)
            completionHandler(true)
        case "Disconnect":
            if UserDefaults.shared.networkProtectionEnabled {
                Application.shared.connectionManager.resetRulesAndDisconnectShortcut(closeApp: true)
                completionHandler(true)
                break
            }
            Application.shared.connectionManager.disconnectShortcut(closeApp: true)
            completionHandler(true)
        default:
            completionHandler(false)
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard Application.shared.authentication.isLoggedIn, Application.shared.serviceStatus.isActive else { return false }
        
        switch userActivity.activityType {
        case UserActivityType.Connect:
            if UserDefaults.shared.networkProtectionEnabled {
                Application.shared.connectionManager.resetRulesAndConnectShortcut(closeApp: true)
                break
            }
            Application.shared.connectionManager.connectShortcut(closeApp: true)
        case UserActivityType.Disconnect:
            if UserDefaults.shared.networkProtectionEnabled {
                Application.shared.connectionManager.resetRulesAndDisconnectShortcut(closeApp: true)
                break
            }
            Application.shared.connectionManager.disconnectShortcut(closeApp: true)
        default:
            log(info: "No such user activity")
        }
        
        return false
    }
    
}
