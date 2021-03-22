//
//  AppDelegate.swift
//  coksabu
//
//  Created by Yojic Jung on 2021/02/12.
//

import UIKit
import Firebase
import UserNotifications


@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    static var apnToken: String?
    
    var window: UIWindow?
    
    
    //앱이 처음 실행될때, terminate 됬다가 다시 실행됬을때
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        FirebaseApp.configure()
        if #available(iOS 10.0, *) {
          // For iOS 10 display notification (sent via APNS)
          UNUserNotificationCenter.current().delegate = self

          let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
          UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })
        } else {
          let settings: UIUserNotificationSettings =
          UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
          application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        Messaging.messaging().token { token, error in
          if let error = error {
            NSLog("Error fetching FCM registration token: \(error)")
          } else if let token = token {
            NSLog("FCM registration token: \(token)")
          
          }
        }
        
        return true
    }

    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        let token = deviceToken as NSData
        let token2 = token.map{String(format:"%02x",$0)}.joined()
        NSLog("디바이스 APN 토큰 : ", token2)
        AppDelegate.apnToken=token2
    }
    
    //푸시 알림 받으면 실행되는 메소드
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NSLog("푸시알림받음")
        ViewController.badgeCount = ViewController.badgeCount+1
        UIApplication.shared.applicationIconBadgeNumber = ViewController.badgeCount
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    
    //푸시 알림 클릭하고 들어오면 실행되는 메소드
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void){
        
        NSLog("푸시 클릭하고 들어옴")
        let pushUrl = response.notification.request.content.userInfo["link"] as? String
        NSLog((pushUrl ?? "링크 없음") as String)
        if pushUrl !=  nil {
            NSLog("앱델레케이트 푸시타고 들어옴, 링크있음")
            if UIApplication.shared.applicationState == .active {
                NSLog("포그라운드에서 클릭")
                let vc = UIApplication.shared.windows.first!.rootViewController as! ViewController
                vc.spinnerON()
                vc.loadWebPage(pushUrl!)
            }else{
                NSLog("백그라운드에서 클릭")
                let userDefault = UserDefaults.standard
                userDefault.set(pushUrl, forKey: "PUSH_URL")
                userDefault.synchronize()
            }
        }else{
            NSLog("앱델레케이트 푸시타고 들어옴, 링크 없음")
        }
        completionHandler()
    }
    
    
    //포그라운드에서 푸시알림 발생시 실행
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NSLog("willpresent")
        //포그라운드에서 푸시알림 받을 수 있음
        completionHandler([.banner, .badge, .sound])
    }
    
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
      NSLog("Firebase registration token: \(String(describing: fcmToken))")
      let dataDict:[String: String] = ["token": fcmToken ?? ""]
      NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
      // TODO: If necessary send token to application server.
      // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    
    
}

