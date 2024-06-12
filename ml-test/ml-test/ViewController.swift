//
//  ViewController.swift
//  ml-test
//
//  Created by 吉田成秀 on 2024/06/07.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var text: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        text.text = main()
    }

    func main() -> String {
        // プーリングサイズを定義
        let poolSize = 250
        
        // プーリング関数
        func maxPooling(_ input: [Double], poolSize: Int) -> [Double] {
            var pooled: [Double] = []
            for i in stride(from: 0, to: input.count, by: poolSize) {
                let poolWindow = input[i..<min(i + poolSize, input.count)]
                pooled.append(poolWindow.max() ?? 0.0)
            }
            return pooled
        }
        
        let signal1:[Double] = [0.0]
        let signal2:[Double] = [0.0]

        // 学習データの入力
        var inputs: [[Double]] = [
            signal1,  // 学習データ1
            signal2  // 学習データ2
        ]

        var targets: [[Double]] = [
            [1.0, 0.0],  // 学習データ1のターゲット
            [0.0, 1.0],  // 学習データ2のターゲット
        ]

        // 学習データにプーリングを適用
        inputs = inputs.map { maxPooling($0, poolSize: poolSize) }
        
        // プーリング後のサイズを自動決定
        let inputSize = inputs[0].count
        print(inputSize)

        // 全結合層のインスタンス化
        let fcLayer = MultipleLinearRegression(inputSize: inputSize, outputSize: 2)

        // 学習（複数回繰り返す）
        let numEpochs = 100000
        let learningRate = 0.001

        for epoch in 0..<numEpochs {
            for i in 0..<inputs.count {
                let predicted = fcLayer.forward(inputs[i])
                let target = targets[i]
                let loss = fcLayer.crossEntropyLoss(predicted: predicted, target: target)
                fcLayer.backward(inputs: inputs[i], predicted: predicted, target: target, learningRate: learningRate)
            }
            if epoch % 10000 == 0 {
                print("epoch: \(epoch)")
            }
        }
        
        let mydata = [0.0] // テスト分類用データ

        // 予測データにプーリングを適用
        let testData = maxPooling(mydata, poolSize: poolSize)
        let predicted = fcLayer.forward(testData)
        print("Predicted: \(predicted)")

        // 結果の出力
        return "\(predicted)"
    }
}
