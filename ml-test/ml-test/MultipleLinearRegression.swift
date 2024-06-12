//
//  MultipleLinearRegression.swift
//  ml-test
//
//  Created by 吉田成秀 on 2024/06/07.
//

import Foundation

import Foundation

class MultipleLinearRegression {
    private var inputSize: Int       // 入力サイズ
    private var outputSize: Int      // 出力サイズ
    private var weights: [[Double]]  // 重み行列
    private var biases: [Double]     // バイアス

    init(inputSize: Int, outputSize: Int) {
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.weights = Array(repeating: Array(repeating: 0.0, count: inputSize), count: outputSize)
        self.biases = Array(repeating: 0.0, count: outputSize)
        initializeWeights()
        initializeBiases()
    }

    // 重みの初期化（He初期化）
    private func initializeWeights() {
        let scale = sqrt(2.0 / Double(inputSize))
        for i in 0..<outputSize {
            for j in 0..<inputSize {
                weights[i][j] = Double.random(in: 0...1) * scale
            }
        }
    }

    // バイアスの初期化
    private func initializeBiases() {
        biases = Array(repeating: 0.0, count: outputSize)
    }

    // ReLU活性化関数
    private func relu(_ x: Double) -> Double {
        return max(0.0, x)
    }

    // softmax活性化関数
    private func softmax(_ inputs: [Double]) -> [Double] {
        var outputs = inputs.map { exp($0) }
        let sumExp = outputs.reduce(0, +)
        outputs = outputs.map { $0 / sumExp }
        return outputs
    }

    // 順伝播
    func forward(_ inputs: [Double]) -> [Double] {
        var outputs = [Double](repeating: 0.0, count: outputSize)
        for i in 0..<outputSize {
            var sum = 0.0
            for j in 0..<inputSize {
                sum += weights[i][j] * inputs[j]
            }
            outputs[i] = relu(sum + biases[i])
        }
        return softmax(outputs)
    }

    // 交差エントロピー誤差
    func crossEntropyLoss(predicted: [Double], target: [Double]) -> Double {
        var loss = 0.0
        for i in 0..<outputSize {
            loss += target[i] * log(predicted[i])
        }
        return -loss
    }

    // 逆伝播
    func backward(inputs: [Double], predicted: [Double], target: [Double], learningRate: Double) {
        var gradients = [Double](repeating: 0.0, count: outputSize)
        for i in 0..<outputSize {
            gradients[i] = predicted[i] - target[i]
        }

        for i in 0..<outputSize {
            for j in 0..<inputSize {
                weights[i][j] -= learningRate * gradients[i] * inputs[j]
            }
            biases[i] -= learningRate * gradients[i]
        }
    }
}
