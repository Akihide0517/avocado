//
//  KMeans.swift
//  audioavocado -Test
//
//  Created by 吉田成秀 on 2023/11/10.
//

import Foundation
import UIKit

// ユーティリティ関数: 2つのベクトルのユークリッド距離を計算
func distance(_ a: [Double], _ b: [Double]) -> Double {
    return sqrt(zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +))
}

// ユーティリティ関数: ベクトルの平均を計算
func calculateMean(_ vectors: [[Double]]) -> [Double] {
    guard !vectors.isEmpty else { return [] }

    let dimensions = vectors[0].count
    var mean = [Double](repeating: 0.0, count: dimensions)

    for i in 0..<dimensions {
        mean[i] = vectors.reduce(0.0) { $0 + $1[i] } / Double(vectors.count)
    }

    return mean
}

// K-meansクラス
class KMeans {
    var clusters: [[Double]]
    
    init(initialClusters: [[Double]]) {
        self.clusters = initialClusters
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // データポイントを最も近いクラスタに関連付けるメソッド
    private func assignToClusters(data: [[Double]]) -> [Int] {
        var labels = [Int](repeating: 0, count: data.count)

        for i in 0..<data.count {
            var minDistance = Double.greatestFiniteMagnitude

            for (index, cluster) in clusters.enumerated() {
                let dist = distance(data[i], cluster)

                if dist < minDistance {
                    minDistance = dist
                    labels[i] = index
                }
            }
        }

        return labels
    }

    // 中心をクラスタの平均に移動するメソッド
    private func updateCentroids(data: [[Double]], labels: [Int]) {
        var newClusters = [[Double]](repeating: [0.0, 0.0], count: clusters.count)
        var counts = [Int](repeating: 0, count: clusters.count)

        for i in 0..<data.count {
            let clusterIndex = labels[i]
            newClusters[clusterIndex][0] += data[i][0]
            newClusters[clusterIndex][1] += data[i][1]
            counts[clusterIndex] += 1
        }

        for i in 0..<clusters.count {
            if counts[i] > 0 {
                newClusters[i][0] /= Double(counts[i])
                newClusters[i][1] /= Double(counts[i])
            }
        }

        clusters = newClusters
    }

    // K-meansアルゴリズムを実行するメソッド
    func runKMeans(data: [[Double]], iterations: Int) -> [Int] {
        var labels = [Int](repeating: 0, count: data.count)

        for _ in 0..<iterations {
            labels = assignToClusters(data: data)
            updateCentroids(data: data, labels: labels)
        }

        return labels
    }
}

class KMeansController: UIViewController{
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 使用例
        let signal1 = SaveTrueData
        let signal2 = SaveFalseData
        let signal3 = SaveDataPoint
        let initialClusters = [maxPoolingArray(inputArray: signal1.map { Double($0) }), maxPoolingArray(inputArray: signal2.map { Double($0) })]

        let inputSignal = [
            maxPoolingArray(inputArray: signal3.map { Double($0) }),
            // ... add more data points as needed
        ]

        let kmeans = KMeans(initialClusters: initialClusters)
        let labels = kmeans.runKMeans(data: inputSignal, iterations: 10)

        // クラスタに所属するデータを表示
        for label in Set(labels) {
            print("Cluster \(label) data:")
            for (index, dataPoint) in inputSignal.enumerated() {
                if labels[index] == label {
                    print("\(dataPoint[0]), \(dataPoint[1])")
                    displayClusterData(labels: label, result: "\(dataPoint[0]), \(dataPoint[1])")
                }
            }
            print("---")
        }
    }
    
    func maxPoolingArray(inputArray: [Double]) -> [Double] {
        var outputArray: [Double] = []

        // 入力配列の要素数が奇数の場合は、最後の要素はそのまま出力配列に追加
        let lastIndex = inputArray.count % 2 == 0 ? inputArray.count - 2 : inputArray.count - 1

        // 隣り合う要素をペアにして最大値を取り、新しい要素として結合
        for i in stride(from: 0, to: lastIndex, by: 2) {
            let maxValue = max(inputArray[i], inputArray[i + 1])
            outputArray.append(maxValue)
        }

        return outputArray
    }
    
    @IBOutlet weak var cluster1Label: UILabel!
    @IBOutlet weak var cluster2Label: UILabel!
    
    // クラスタに所属するデータをUILabelに表示するメソッド
    func displayClusterData(labels: Int, result: String) {
        var cluster1Data = ""
        var cluster2Data = ""

        switch labels {
        case 0:
            cluster1Data += result
        case 1:
            cluster2Data += result
        // Add more cases if you have more clusters
        default:
            break
        }
        // クラスタ1とクラスタ2のデータをUILabelに表示
        cluster1Label.text = "Cluster 1 Data:" + "\(cluster1Data)"
        cluster2Label.text = "Cluster 2 Data:" + "\(cluster2Data)"
    }
    
    //Debug1
    @IBAction func DebugMode1ValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            Debug1 = true
        } else {
            // UISwitchがオフの場合
            Debug1 = false
        }
    }
    
    //Debug2
    @IBAction func DebugMode2ValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            Debug2 = true
        } else {
            // UISwitchがオフの場合
            Debug2 = false
        }
    }
}
