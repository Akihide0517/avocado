//
//  AppDelegate.swift
//  audioavocado -Test
//
//  Created by 吉田成秀 on 2023/10/16.
//

import UIKit

var wave: [CGFloat] = []
var reversewave:[CGFloat] = []
var Level: Bool = false
var peakMode: Bool = true
var peakDir: Bool = false
var graphMode: Bool = true
var IFFTMode: Bool = true
var blockSize = 2
var threads = 0
var selfMode:Bool = false
var envelope_reversedMode:Bool = false
var floatArray:[Float] = []

var Processing:Int = 0
var convolutionMode1:[CGFloat] = []
var convolutionMode2:[CGFloat] = []
var FFTProcessing:Int = 0
var debugGraphMode:Int = 0
var convolutionMode:Int = 0
var convolutionModeA:Int = 0
var convolutionModeB:Int = 0
var reversefloatArray:[CGFloat] = []
var convolutionFFTSelect:Bool = false

var windowSize:Int = 4096
var nyquist:Int = 65000

var nyquistMode: Bool = false
var windowMode: Bool = false

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
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


}

