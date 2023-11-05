//
//  SelfFFTModeSettingViewController.swift
//  audioavocado -Test
//
//  Created by 吉田成秀 on 2023/10/30.
//https://zenn.dev/moutend/articles/e39f4f162db475bea8c8
//Yoshiyuki Koyanagi様にはお世話になりましたのでここで敬意を表します

import Foundation
import UIKit

import AVFoundation
import Accelerate
import AudioToolbox

class SelfFFTModeSettingViewController: UIViewController {
    
    @IBOutlet weak var sinComponentLabel: UILabel!
    @IBOutlet weak var cosComponentLabel: UILabel!
    @IBOutlet weak var frequencyLabel: UILabel!
    @IBOutlet weak var frequencyTextField: UITextField!
    @IBOutlet weak var lengthTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the initial values of the sliders
        sinSlider.value = 0.5
        cosSlider.value = 0.5
        sinComponentLabel.text = "sinCompo: 0.0"
        cosComponentLabel.text = "cosCompo: 0.0"
        frequencyLabel.text = "freq: 0.0"
        
        convolutionMode1 = []
        convolutionMode2 = []
        
        // Create a waveform
        waveform = Waveform(frequency: 100.0, sampleRate: 44100.0, duration: 1.0)
        frequencyTextField.addDoneButton()
        lengthTextField.addDoneButton()
    }
    
    //FFTボタンに影響するボタン
    @IBOutlet weak var selfModeSwitch: UISwitch!
    @IBAction func selfModeValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            selfMode = true
        } else {
            // UISwitchがオフの場合
            selfMode = false
        }
    }
    
    @IBAction func ValueChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            Processing = 0
        case 1:
            Processing = 1
        default:
            print("存在しない番号")
        }
    }
    
    @IBAction func ValueChanged2(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            convolutionMode = 0
        case 1:
            convolutionMode = 1
        default:
            print("存在しない番号")
        }
    }
    
    @IBAction func ValueChanged3(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            FFTProcessing = 0
        case 1:
            FFTProcessing = 1
        case 2:
            FFTProcessing = 2
        default:
            print("存在しない番号")
        }
    }
    
    @IBAction func ValueChanged4(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            convolutionModeA = 0
        case 1:
            convolutionModeA = 1
            convolutionMode1 = floatArray.map { CGFloat($0) }
        default:
            print("存在しない番号")
        }
    }
    
    @IBAction func ValueChanged5(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            convolutionModeB = 0
        case 1:
            convolutionModeB = 1
            convolutionMode2 = reversefloatArray
            //使用例
           if let envelopedFloatArray = loadWavFileAndCreateEnvelope(fileName: "swept_sine", fileExtension: "wav", envelopeDuration: 5.0) {
               convolutionMode2 = envelopedFloatArray
               print("WAVファイルを逆順に変更し、エンベロープを作成しました。",convolutionMode2[100], convolutionMode2[239997])
           } else {
               print("WAVファイルの変換に失敗しました。")
           }
            
            print(convolutionMode2.count)
        case 2:
            convolutionModeB = 2
            var URLName = ""
            if(!envelope_reversedMode){
                URLName = "envelope"
            }else{
                URLName = "envelope_reversed"
            }
            if let wavFloatArray = wavToFloatArray(fileName: URLName, fileExtension: "wav") {
                convolutionMode2 = wavFloatArray
            } else {
                print("WAVファイルの変換に失敗しました。")
            }
        default:
            print("存在しない番号")
        }
    }
    
    @IBAction func graphChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            debugGraphMode = 0
        case 1:
            debugGraphMode = 1
        default:
            print("存在しない番号")
        }
    }
    
    @IBOutlet weak var envelope_reversedSwitch: UISwitch!
    @IBAction func envelope_reversedValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            envelope_reversedMode = true
        } else {
            // UISwitchがオフの場合
            envelope_reversedMode = false
        }
    }
    
    @IBOutlet weak var convolutionFFTSelectSwitch: UISwitch!
    @IBAction func convolutionFFTSelectChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            convolutionFFTSelect = true
        } else {
            // UISwitchがオフの場合
            convolutionFFTSelect = false
        }
    }
    
    func loadWavFileAndCreateEnvelope(fileName: String, fileExtension: String, envelopeDuration: TimeInterval) -> [CGFloat]? {
        if let wavURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            do {
                let audioFile = try AVAudioFile(forReading: wavURL)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)

                // サンプルデータを読み込むためのバッファを作成
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
                try audioFile.read(into: buffer!)

                // サンプルデータを[Float]に変換
                let floatArray = Array(UnsafeBufferPointer(start: buffer!.floatChannelData?[0], count: Int(frameCount)))

                // サンプルデータを逆順に変更
                let reversedFloatArray = floatArray.reversed()

                // エンベロープのサンプル数を計算
                let envelopeSampleCount = Int(format.sampleRate * envelopeDuration)

                // エンベロープ用のデータを生成
                var envelopeArray: [Float] = []
                for i in 0..<envelopeSampleCount {
                    let envelopeValue = Float(i) / Float(envelopeSampleCount - 1)
                    envelopeArray.append(envelopeValue)
                }

                // エンベロープをWAVデータの長さに合わせる
                while envelopeArray.count < reversedFloatArray.count {
                    envelopeArray.append(0.0)
                }

                // エンベロープを適用
                let envelopedFloatArray = zip(reversedFloatArray, envelopeArray).map { $0 * $1 }

                // 最終的に[Float]から[CGFloat]へ変換
                return envelopedFloatArray.map { CGFloat($0) }
            } catch {
                print("WAVファイルの読み込みに失敗しました: \(error.localizedDescription)")
            }
        } else {
            print("WAVファイルが見つかりません")
        }

        return nil
    }
    
    func wavToFloatArray(fileName: String, fileExtension: String) -> [CGFloat]? {
        if let wavURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            do {
                let audioFile = try AVAudioFile(forReading: wavURL)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)

                // サンプルデータを読み込むためのバッファを作成
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)

                try audioFile.read(into: buffer!)

                // サンプルデータを[CGFloat]に変換
                let floatArray = Array(UnsafeBufferPointer(start: buffer!.floatChannelData?[0], count: Int(frameCount)))

                return floatArray.map { CGFloat($0) }
            } catch {
                print("WAVファイルの読み込みに失敗しました: \(error.localizedDescription)")
            }
        } else {
            print("WAVファイルが見つかりません")
        }

        return nil
    }
    
    @IBOutlet weak var sinSlider: UISlider!
    @IBOutlet weak var cosSlider: UISlider!

    private var waveform: Waveform!
    private var audioFile: ExtAudioFileRef?
    
    @IBAction func sinSliderChanged(_ sender: UISlider) {
        // Update the sin component
        waveform.sinComponent = sender.value

        // Update the waveform
        waveform.update(frequency: Float(frequencyTextField.text ?? "0.0")!)
    }

    @IBAction func cosSliderChanged(_ sender: UISlider) {
        // Update the cos component
        waveform.cosComponent = sender.value

        // Update the waveform
        waveform.update(frequency: Float(frequencyTextField.text ?? "0.0")!)
    }

    //現在の技術力では作成した波形を再生することは不可能
    @IBAction func playButtonTapped(_ sender: Any) {
        if(FFTProcessing == 0){
            //sin cos -> 複素数
            
            waveform.update(frequency: Float(frequencyTextField.text ?? "0.0")!)
            
            let graphView = PointGraphView()
            // dataPointsプロパティの型をCGPointに変更する
            //var _: [CGPoint] = []
            
            // map関数でCGFloat型の値を返すようにする
            graphView.dataPoints = waveform.complexSamples.map { CGFloat($0.real) }
            
            view.addSubview(graphView)
            // グラフの位置やサイズを調整（Auto Layoutを使用する場合）
            graphView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                graphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                graphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                graphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                graphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // グラフの高さを設定
            ])
            
            sinComponentLabel.text = "sin: \(waveform.sinComponent)"
            cosComponentLabel.text = "cos: \(waveform.cosComponent)"
            frequencyLabel.text = "freq: \(waveform.Frequency)"
        }else if(FFTProcessing == 1){
            //FFT
            if(debugGraphMode == 0){
                let floatsSlice = floatArray
                
                let complexGraphView = ComplexGraphView()
                let complexDataPoints: [Complex64] = FFT(signal: floatsSlice).limitLength(Int(lengthTextField.text ?? "0.0")!)
                complexGraphView.complexDataPoints = complexDataPoints
                view.addSubview(complexGraphView)
                complexGraphView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    complexGraphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    complexGraphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    complexGraphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    complexGraphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // グラフの高さを設定
                ])
                
                
                sinComponentLabel.text = "sin: \(waveform.sinComponent)"
                cosComponentLabel.text = "cos: \(waveform.cosComponent)"
                frequencyLabel.text = "freq: \(waveform.Frequency)"
                
            }else{
                let graphView = PointGraphView()
                //var dataPoints: [CGPoint] = []
                
                let floatsSlice = floatArray
                
                // map関数でCGFloat型の値を返すようにする
                graphView.dataPoints = toComplex(FFT(signal: floatsSlice).limitLength(Int(lengthTextField.text ?? "0.0")!)).map { CGFloat($0.real) }
                
                view.addSubview(graphView)
                // グラフの位置やサイズを調整（Auto Layoutを使用する場合）
                graphView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    graphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    graphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    graphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    graphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // グラフの高さを設定
                ])
            }
        }else{
            //FFTenvelope
            if(debugGraphMode == 0){
                var URLName = ""
                if(!envelope_reversedMode){
                    print("envelope")
                    URLName = "envelope"
                }else{
                    print("envelope_reversed")
                    URLName = "envelope_reversed"
                }
                
                if let wavFloatArray = wavToFloatArray(fileName: URLName, fileExtension: "wav") {
                    convolutionMode2 = wavFloatArray
                } else {
                    print("WAVファイルの変換に失敗しました。")
                }
                
                if(selfMode){
                    
                    let complexGraphView = ComplexGraphView()
                    let complexDataPoints: [Complex64] = FFT(signal: convolutionMode2.map { Float($0) }).limitLength(Int(lengthTextField.text ?? "0.0")!)
                    complexGraphView.complexDataPoints = complexDataPoints
                    view.addSubview(complexGraphView)
                    complexGraphView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        complexGraphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        complexGraphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        complexGraphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                        complexGraphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // グラフの高さを設定
                    ])
                }else{
                    let graphView = PointGraphView()
                    // map関数でCGFloat型の値を返すようにする
                    graphView.dataPoints = convolutionMode2
                    
                    view.addSubview(graphView)
                    // グラフの位置やサイズを調整（Auto Layoutを使用する場合）
                    graphView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        graphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        graphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        graphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                        graphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // グラフの高さを設定
                    ])
                }
                
                
                sinComponentLabel.text = "sin: \(waveform.sinComponent)"
                cosComponentLabel.text = "cos: \(waveform.cosComponent)"
                frequencyLabel.text = "freq: \(waveform.Frequency)"
                
            }else{
                let graphView = PointGraphView()
                //var dataPoints: [CGPoint] = []
                
                let floatsSlice = floatArray
                
                // map関数でCGFloat型の値を返すようにする
                graphView.dataPoints = toComplex(FFT(signal: floatsSlice).limitLength(Int(lengthTextField.text ?? "0.0")!)).map { CGFloat($0.real) }
                
                view.addSubview(graphView)
                // グラフの位置やサイズを調整（Auto Layoutを使用する場合）
                graphView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    graphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    graphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    graphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    graphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2) // グラフの高さを設定
                ])
            }
        }
        
        if(convolutionMode == 0){
            print("convolutionMode == 0",convolutionMode1.count)
            if(convolutionModeA == 0){
                print("A == 0, waveform.complexSamples",convolutionMode1.count)
                convolutionMode1 = waveform.complexSamples.map { CGFloat($0.real) }
            }else if (convolutionModeA == 1){
                if(!envelope_reversedMode){
                    print("A == 1, floatArray",convolutionMode1.count)
                    convolutionMode1 = floatArray.map { CGFloat($0) }
                    if let wavFloatArray = wavToFloatArray(fileName: "swept_sine", fileExtension: "wav") {
                        convolutionMode1 = wavFloatArray
                        print(convolutionMode1[1],convolutionMode1[1000],convolutionMode1.count)
                    } else {
                        print("WAVファイルの変換に失敗しました。")
                    }
                }else{
                    print("A == 1, envelope_reversed",convolutionMode1.count)
                    if let wavFloatArray = wavToFloatArray(fileName: "envelope_reversed", fileExtension: "wav") {
                        convolutionMode1 = wavFloatArray
                        print(convolutionMode1[1],convolutionMode1[1000])
                    } else {
                        print("WAVファイルの変換に失敗しました。")
                    }
                }
            }
        }else if(convolutionMode == 1){
            print("convolutionMode == 1")
            if(convolutionModeB == 0){
                print("B == 0, waveform.complexSamples")
                convolutionMode2 = waveform.complexSamples.map { CGFloat($0.real) }
            }else if (convolutionModeB == 1){
                print("B == 1, reversefloatArray")
                convolutionMode2 = reversefloatArray
            }else if (convolutionModeB == 2){
                print("B == 2")
                var URLName = ""
                if(!envelope_reversedMode){
                    print("envelope")
                    URLName = "envelope"
                    convolutionMode1 = floatArray.map { CGFloat($0) }
                }else{
                    print("envelope_reversed")
                    URLName = "envelope_reversed"
                    convolutionMode1 = floatArray.map { CGFloat($0) }
                }
                if let wavFloatArray = wavToFloatArray(fileName: URLName, fileExtension: "wav") {
                    convolutionMode2 = wavFloatArray
                    print(convolutionMode2[1],convolutionMode2[1000])
                } else {
                    print("WAVファイルの変換に失敗しました。")
                }

            }
        }
    }
    
    func limitLength(_ array: [Float], to length: Int) -> [Float] {
        var limitedArray = array
        if limitedArray.count > length {
            limitedArray.removeLast(limitedArray.count - length)
        }
        return limitedArray
    }

    //信号を複素数に変換するコード
    func FFT(signal: [Float]) -> [Complex64] {
        let log2n = vDSP_Length(log2(Float(signal.count)) + 1)
        let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)!

        var inputReal = [Float](signal)
        var inputImag = [Float](repeating: 0.0, count: signal.count)
        var outputReal = [Float](repeating: 0.0, count: signal.count)
        var outputImag = [Float](repeating: 0.0, count: signal.count)

        inputReal.withUnsafeMutableBufferPointer { inputRealPtr in
            inputImag.withUnsafeMutableBufferPointer { inputImagPtr in
                outputReal.withUnsafeMutableBufferPointer { outputRealPtr in
                    outputImag.withUnsafeMutableBufferPointer { outputImagPtr in
                        let input = DSPSplitComplex(realp: inputRealPtr.baseAddress!, imagp: inputImagPtr.baseAddress!)
                        var output = DSPSplitComplex(realp: outputRealPtr.baseAddress!, imagp: outputImagPtr.baseAddress!)

                        fft.forward(input: input, output: &output)
                    }
                }
            }
        }

        var spectrum = [Complex64](repeating: Complex64(0.0, 0.0), count: signal.count)

        for i in 0 ..< signal.count {
            spectrum[i].real = outputReal[i]
            spectrum[i].imag = outputImag[i]
        }

        return spectrum
    }
    
    func toComplex(_ complex64s: [Complex64]) -> [Complex] {
        var complexes = [Complex]()
        for complex64 in complex64s {
            complexes.append(Complex(real: complex64.real, imag: complex64.imag))
        }
        return complexes
    }
}

struct Waveform {
    var complexSamples: [Complex]
    var sinComponent: Float = 0.5
    var cosComponent: Float = 0.5
    var Frequency: Float = 0

    init(frequency: Float, sampleRate: Float, duration: Float) {
        var complexSamples = [Complex](repeating: Complex(real: 0.0, imag: 0.0), count: Int(duration * sampleRate))

        for i in 0..<complexSamples.count {
            let t = Float(i) / sampleRate
            let sample = sin(2.0 * Float.pi * frequency * t)
            let complexSample = Complex(real: sample, imag: 0.0)
            complexSamples[i] = complexSample
        }

        self.complexSamples = complexSamples
        Frequency = frequency
    }

    var complexPlane: [CGPoint] {
        var complexPlane = [CGPoint](repeating: CGPoint(x: 0.0, y: 0.0), count: complexSamples.count)

        for i in 0..<complexPlane.count {
            let complexSample = complexSamples[i]
            complexPlane[i].x = CGFloat(complexSample.real)
            complexPlane[i].y = CGFloat(complexSample.imag)
        }

        return complexPlane
    }

    var frequencyDomain: [Complex] {
        return complexSamples
    }
    
    mutating func update(frequency: Float) {
        for i in 0..<complexSamples.count {
            let t = Float(i) / 44100
            let sample = sin(2.0 * Float.pi * frequency * t * sinComponent + cosComponent)
            let complexSample = Complex(real: sample, imag: 0.0)
            complexSamples[i] = complexSample
            Frequency = frequency
        }
    }
}

struct Complex {
    var real: Float
    var imag: Float
}

class PointGraphView: UIView {
    var dataPoints: [CGFloat] = [] // グラフのデータポイント

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 背景をクリア
        context.clear(rect)

        // グラフを描画
        drawGraph(in: context, within: rect)
    }

    private func drawGraph(in context: CGContext, within rect: CGRect) {
        // データポイントの数を取得
        let dataCount = dataPoints.count
        guard dataCount > 1 else { return }

        // グラフの線の色や太さを設定
        context.setStrokeColor(UIColor.blue.cgColor)
        context.setLineWidth(2.0)

        // X軸とY軸のスケールを計算
        let maxX = CGFloat(dataCount - 1)
        let maxY = dataPoints.max() ?? 1.0 // データポイントの最大値を取得
        let xScale = rect.width / maxX
        let yScale = rect.height / maxY

        // パスを初期化
        context.beginPath()

        // データポイントをつなげる線を描画
        for (index, dataPoint) in dataPoints.enumerated() {
            let x = CGFloat(index) * xScale
            let y = rect.height - dataPoint * yScale // グラフが上から下に描画されるため、Y座標を反転

            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // パスを描画
        context.strokePath()
    }
}

extension UITextField {
    func addDoneButton() {
        let toolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.sizeToFit()

        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(resignFirstResponder))
        toolbar.items = [doneButton]

        inputAccessoryView = toolbar
    }
}

struct Complex64 {
    var real: Float
    var imag: Float

    init(_ r: Float, _ i: Float) {
        self.real = r
        self.imag = i
    }
}

class ComplexGraphView: UIView {
    var complexDataPoints: [Complex64] = [] // 複素数データポイント

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 背景をクリア
        context.clear(rect)

        // グラフを描画
        drawComplexGraph(in: context, within: rect)
    }

    private func drawComplexGraph(in context: CGContext, within rect: CGRect) {
        // 複素数データポイントの数を取得
        let dataCount = complexDataPoints.count
        guard dataCount > 1 else { return }

        // グラフの線の色や太さを設定
        context.setStrokeColor(UIColor.blue.cgColor)
        context.setLineWidth(2.0)

        // X軸とY軸のスケールを計算
        let maxX = CGFloat(dataCount - 1)
        let maxY = CGFloat(complexDataPoints.map { max($0.real, $0.imag) }.max() ?? 1.0)
        let xScale = rect.width / maxX
        let yScale = rect.height / maxY

        // パスを初期化
        context.beginPath()

        // 複素数データポイントをつなげる線を描画
        for (index, complexDataPoint) in complexDataPoints.enumerated() {
            let x = CGFloat(index) * xScale
            let yReal = rect.height - CGFloat(complexDataPoint.real) * yScale
            let yImag = rect.height - CGFloat(complexDataPoint.imag) * yScale

            if index == 0 {
                context.move(to: CGPoint(x: x, y: yReal))
            } else {
                context.addLine(to: CGPoint(x: x, y: yReal))
            }
        }

        // パスを描画
        context.strokePath()
    }
}

extension Array {
    func limitLength(_ maxLength: Int) -> Array {
        if count <= maxLength {
            return self
        } else {
            return Array(self[0..<maxLength])
        }
    }
}
