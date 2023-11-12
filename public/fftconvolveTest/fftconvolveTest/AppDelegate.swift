//
//  AppDelegate.swift
//  fftconvolveTest
//
//  Created by 吉田成秀 on 2023/11/07.
//

import UIKit

var ComplexResultConvolution:[Complex64] = []
var TimeResultConvolution:[Float] = []

var SaveTrueData:[Float] = []
var SaveFalseData:[Float] = []
var SaveDataPoint:[Float] = []

//デバック用（どうしてもイレギュラーなテストを行いたい時のみ書いてください）
var Debug1:Bool = false//graphView in 95
var Debug2:Bool = false//View in 140
//

//swift言語に複素数が表現できないことを補完するコード
struct Complex64 {
    var real: Float
    var imag: Float

    init(_ r: Float, _ i: Float) {
        self.real = r
        self.imag = i
    }

    // 自身と他のComplex64を足すための+=演算子の実装
    static func += (lhs: inout Complex64, rhs: Complex64) {
        lhs.real += rhs.real
        lhs.imag += rhs.imag
    }
}

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

