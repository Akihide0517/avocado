//
//  FFTController.swift
//  audioavocado -Test
//
//  Created by 吉田成秀 on 2023/10/19.
//

import Foundation
import UIKit
import Accelerate
import DGCharts
import Dispatch
import simd
import TensorSwift
import AVFAudio

class FFTController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var counter: UILabel!
    @IBOutlet weak var numberTextField: UITextField!
    @IBOutlet weak var nyquistTextField: UITextField!
    
    var chartView: LineChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("opend!")
        
        numberTextField.delegate = self
        nyquistTextField.delegate = self
        
        if(chartView != nil){
            chartView.removeFromSuperview()
        }
        
        // グラフ表示の事前準備
        chartView = LineChartView()
        chartView.frame = CGRect(x: 20, y: 20, width: 300, height: 200) // Set frame as needed
        view.addSubview(chartView)
        print("Create the LineChartView end")
        
        if(selfMode){//ok!
            selectMode()
        }else{
            Processing = 1
            debugGraphMode = 1
            convolutionMode1 = wave
            convolutionMode2 = reversewave
            selectMode()
        /*
            //畳み込みを行うモード
            
            // 畳み込まれた結果のデータ
            print("B.wave:",wave.count,wave[100])
            var convolutionResult = (convolutionFFTBlockMulti(signal1: wave.map { Float($0) }, signal2: reversewave.map { Float($0) }, blockSize: blockSize))
                
            //convolutionResultのグラフの描画
            if(graphMode){
                let graphView = GraphView()
                graphView.dataPoints = convolutionResult.map { CGFloat(Float($0)) }
                view.addSubview(graphView)
                // グラフの位置やサイズを調整（Auto Layoutを使用する場合）
                graphView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    graphView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    graphView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    graphView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    graphView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3) // グラフの高さを設定
                ])
            }
            print("convolution end",convolutionResult.count,":",convolutionResult[100])
                
            // ピークの位置を見つける
            let peakIndices = findPeaks(convolutionResult.map { CGFloat($0) })!
            print("peakIndices end",peakIndices)
            
            //ピークの扱い方に関するロジック
            var fftResult:[Double] = []
            if(!peakMode){
                // ピークを中心にデータポイントを取り出し
                var extractedData = extractDataAroundPeaks(convolutionResult.map { CGFloat($0) }, peakIndex: peakIndices, dataPointsCount: 48000)
                print("extractedData end",extractedData.count)
                
                //畳み込み結果をFFT
                fftResult = performFFT(on: extractedData)
                print("fftResult end")
                
            }else{
                // ピーク以降、以前のデータポイントを畳み込み結果から取り出し
                var extractedData = extractDataAfterPeak(convolutionResult.map { CGFloat($0) }, peakIndex: peakIndices, dataPointsCount: 48000)
                if(peakDir){
                    extractedData = extractDataAfterPeak2(convolutionResult.map { CGFloat($0) }, peakIndex: peakIndices, dataPointsCount: 48000)
                }
                print("extractedData end",extractedData.count)
                
                //畳み込み結果をFFT
                fftResult = performFFT(on: extractedData)
                print("fftResult end")
                
            }
            //グラフで表示
            DrawGraph(signal: fftResult)
            print("all opend!")
        */
        }
        //終了時刻を表示
        ViewNowTime()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // キーボードを閉じる
        textField.resignFirstResponder()
        return true
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
    
    @IBAction func getNumberButtonTapped(_ sender: UIButton) {
        if let text = numberTextField.text, let number = Int(text) {
            // UITextFieldから数字を取得
            windowSize = number
            print("Window入力された数字は: \(windowSize)")
        } else {
            // 数字が無効な場合のエラーハンドリング
            print("無効な入力です")
        }
        
        if let text = nyquistTextField.text, let number = Int(text) {
            // UITextFieldから数字を取得
            nyquist = number
            print("nyquist入力された数字は: \(nyquist)")
        } else {
            // 数字が無効な場合のエラーハンドリング
            print("無効な入力です")
        }
        viewDidLoad()
    }
    
    func selectMode(){
        //デバックようのモード
        print("USED selfMode",convolutionMode1.count,convolutionMode2.count)
        
        var inportwave:[Float] = []
        var inportwave2:[Complex64] = []
        
        if(convolutionMode1 == []){
            print("convolutionMode1がないのでwaveで補完",convolutionMode1.count)
            convolutionMode1 = wave
        }
        
        if(convolutionMode2 == []){
            print("convolutionMode2がないのでreversewaveで補完",convolutionMode2.count)
            if let envelopedFloatArray = loadWavFileAndCreateEnvelope(fileName: "swept_sine", fileExtension: "wav", envelopeDuration: 5.0) {
                convolutionMode2 = envelopedFloatArray
                print("WAVファイルを逆順に変更し、エンベロープを作成しました。",convolutionMode2[100], convolutionMode2[239997])
            } else {
                print("WAVファイルの変換に失敗しました。")
            }
        }
        
        if convolutionMode1.count < convolutionMode2.count {
            // reversewaveがwaveより短い場合、waveの長さに合わせてデータを補填
            let diffCount = convolutionMode2.count - convolutionMode1.count
            let paddingData: [CGFloat] = Array(repeating: 0.0, count: diffCount)
            convolutionMode1.append(contentsOf: paddingData)
            print("convolutionMode1が短い")
        }
        
        if convolutionMode2.count < convolutionMode1.count {
            // reversewaveがwaveより短い場合、waveの長さに合わせてデータを補填
            let diffCount = convolutionMode1.count - convolutionMode2.count
            let paddingData: [CGFloat] = Array(repeating: 0.0, count: diffCount)
            convolutionMode2.append(contentsOf: paddingData)
            print("convolutionMode2が短い")
        }
        
        if(Processing == 0){//ok!
            print("USED FFT")
            
            //print("USED reverse swipt-sine FFT")
            //inportwave = complexToFloatArray(FFT(signal: reversewave.map { Float($0) }))
            
            print("USED swipt-sine FFT",convolutionMode1.count)
            inportwave = convolutionMode1.map { Float($0) }
            
        }else if(Processing == 1){
            if(convolutionFFTSelect){
                print("USED CFFT, 畳み込み前FFTなし")
                inportwave = (convolutionFFTBlockMulti2(signal1: convolutionMode1.map { Float($0) }, signal2: convolutionMode2.map { Float($0) }, blockSize: blockSize))
            }else{
                print("USED CFFT",convolutionMode1.count ,convolutionMode2.count)//<
                print("convolutionMode2",convolutionMode2[100], convolutionMode2[239997])
                
                inportwave2 = (convolutionFFTBlockMulti(signal1: convolutionMode1.map { Float($0) }, signal2: convolutionMode2.map { Float($0) }, blockSize: blockSize))
            }
        }
        
        if(debugGraphMode == 0){
        print("USED Graph")
            
        var entries: [ChartDataEntry] = []
        for (index, magnitude) in (inportwave).enumerated() {
            let entry = ChartDataEntry(x: Double(index), y: Double(magnitude))
            entries.append(entry)
        }
        
        // Create a data set and a data object for the chart
        let dataSet = LineChartDataSet(entries: entries, label: "FFT Magnitudes")
        let data = LineChartData(dataSet: dataSet)

        // Customize the chart appearance (optional)
        chartView.xAxis.labelPosition = .bottom
        chartView.rightAxis.enabled = false
        dataSet.drawCirclesEnabled = false

        // Set the data for the chart
        chartView.data = data
        }else{
            print("USED performFFT Graph")//<
            
            var inputwave = ifft(fft: inportwave2)
            inputwave = limitToNyquistFrequency(array: inputwave, samplingFrequency: Float(nyquist))

            // 周波数を計算
            var frequencies: [Double] = []
            for i in 0..<inputwave.count {
                let frequency = Double(i) / Double(inputwave.count) * 48000.0
                frequencies.append(frequency)
            }

            var entries: [ChartDataEntry] = []
            for (index, complex) in (inputwave).enumerated() {
                let magnitude = sqrt(complex.real * complex.real + complex.imag * complex.imag)
                let entry = ChartDataEntry(x: frequencies[index], y: Double(magnitude))
                entries.append(entry)
            }

            
            // Create a data set and a data object for the chart
            let dataSet = LineChartDataSet(entries: entries, label: "FFT Magnitudes")
            let data = LineChartData(dataSet: dataSet)

            // Customize the chart appearance (optional)
            chartView.xAxis.labelPosition = .bottom
            chartView.rightAxis.enabled = false
            dataSet.drawCirclesEnabled = false

            // Set the data for the chart
            chartView.data = data
        }
    }
    
    func ifft(fft: [Complex64]) -> [Complex64] {
        // Normalize the FFT
        let n = fft.count
        let norm = 2.0 / Double(n)

        // Calculate the inverse FFT
        var ifft = [Complex64](repeating: Complex64(0.0, 0.0), count: n)
        for i in 0 ..< n {
            ifft[i] = Complex64(fft[i].real * Float(norm), -fft[i].imag * Float(norm))
        }

        // Shift the spectrum
        for i in 0 ..< n / 2 {
            ifft[i] = Complex64(ifft[i].real, ifft[n - i - 1].imag)
            ifft[n - i - 1] = Complex64(ifft[i].imag, -ifft[n - i - 1].real)
        }

        // Calculate the magnitude
        var magnitude = [Complex64](repeating: Complex64(0.0, 0.0), count: n)
        for i in 0 ..< n {
            magnitude[i] = Complex64(ifft[i].real * ifft[i].real + ifft[i].imag * ifft[i].imag, 0.0)
        }

        // Return the magnitude
        return magnitude
    }
    
    // ナイキスト周波数以上削除
    func limitToNyquistFrequency(array: [Complex64], samplingFrequency: Float) -> [Complex64] {
        if(!nyquistMode){
            let halfIndex = Int(samplingFrequency / 2)
                var result = array
            for i in Int(halfIndex)..<array.count {
                result[i] = Complex64(0.0, 0.0)
                }

                // ナイキスト周波数以下の周波数の成分を復元
                for i in 0..<halfIndex {
                    result[i] = array[i]
                }

                return result
        }else{
            return array
        }
    }
    
    //ピークを検出し、それ以前を抹消するコード(まだ利用していない。なぜなら用途が意味不明だからである)
    func detectPeaks(data: [Float], threshold: Float, peakWidth: Int, peakType: String) -> [Float] {
        var modifiedData = data
        if peakType == "min" {
            modifiedData = data.map { $0 > threshold ? threshold : $0 }
        } else {
            modifiedData = data.map { $0 < threshold ? threshold : $0 }
        }
        
        var differences = [Float]()
        for i in 1..<modifiedData.count {
            differences.append(modifiedData[i] - modifiedData[i - 1])
        }
        
        var productOfDifferences = [Float]()
        for i in 1..<(differences.count - 1) {
            productOfDifferences.append(differences[i] * differences[i - 1])
        }
        
        var peakPositions = [Int]()
        
        while true {
            if let minIndex = productOfDifferences.firstIndex(of: 0) {
                let firstPeakIndex = peakPositions.first ?? -1
                let distance = abs(minIndex - firstPeakIndex)
                if distance > peakWidth {
                    peakPositions.append(minIndex)
                }
                productOfDifferences[minIndex] = 1
            } else {
                break
            }
        }
        
        if let firstPeak = peakPositions.first, firstPeak < data.count {
            let remainingData = Array(data[firstPeak...])
            return remainingData
        } else {
            return data
        }
    }
    
    @IBOutlet weak var nyquistModeSwitch: UISwitch!

    @IBAction func nyquistModeValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            nyquistMode = true
        } else {
            // UISwitchがオフの場合
            nyquistMode = false
        }
    }
    
    @IBOutlet weak var windowModeSwitch: UISwitch!

    @IBAction func windowModeValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            windowMode = true
        } else {
            // UISwitchがオフの場合
            windowMode = false
        }
    }

    //上画面にグラフを模写するコード
    func DrawGraph(signal: [Double]){
        // Prepare data for the chart
        var entries: [ChartDataEntry] = []
        for (index, magnitude) in signal.enumerated() {
            let entry = ChartDataEntry(x: Double(index), y: magnitude)
            entries.append(entry)
        }
        print("Prepare data for the chart end")
        
        // Create a data set and a data object for the chart
        let dataSet = LineChartDataSet(entries: entries, label: "FFT Magnitudes")
        let data = LineChartData(dataSet: dataSet)
        
        // Customize the chart appearance (optional)
        chartView.xAxis.labelPosition = .bottom
        chartView.rightAxis.enabled = false
        dataSet.drawCirclesEnabled = false
        
        // Set the data for the chart
        chartView.data = data
    }
    
    //現在時刻を表示するためのメソッド
    func ViewNowTime(){
        let currentDate = Date()  // 現在の日時を取得
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"  // 任意の日付/時間フォーマットを指定
        let formattedDate = dateFormatter.string(from: currentDate)
        print("現在の時刻は: \(formattedDate)")
    }
    
    //波形単体の複素数化に使う
    func SelfFFT(signal: [Float]) -> [Complex64] {
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
    
    //畳み込みFFTのロジック
    func convolutionFFTBlockMulti(signal1: [Float], signal2: [Float], blockSize: Int) -> [Complex64] {
        print("signal1",signal1[100], signal1[239997])
        print("signal2",signal2[100], signal2[239997])
        
        // Normal FFT
        let fft1 = applyRectangularWindow(signal: signal1, windowSize: windowSize)
        let fft2 = applyRectangularWindow(signal: signal2, windowSize: windowSize)

        // Overlap add method
        let overlap = blockSize - 1
        let convolutionResultSize = signal1.count + signal2.count - overlap
        var convolutionResult = [Complex64](repeating: Complex64(0.0, 0.0), count: convolutionResultSize)
        
        for i in stride(from: 0, to: signal1.count, by: blockSize - overlap) {
            // Convolution spectrum
            var convolutionSpectrum = [Complex64](repeating: Complex64(0.0, 0.0), count: blockSize)

            // Convolution spectrum calculation
            for j in i ..< min(i + blockSize, signal1.count) {
                convolutionSpectrum[j - i] += Complex64(fft1[i].real * fft2[j].real - fft1[i].imag * fft2[j].imag, fft1[i].real * fft2[j].imag + fft1[i].imag * fft2[j].real)
            }

            // Inverse FFT
            let inverseFFT = convolutionSpectrum.map { $0 }

            // Overlap and add
            for j in 0 ..< inverseFFT.count {
                convolutionResult[i + j] += inverseFFT[j]
            }
        }

        return convolutionResult
    }
    
    func convolutionFFTBlockMulti2(signal1: [Float], signal2: [Float], blockSize: Int) -> [Float] {
        // Normal FFT
        let fft1 = signal1
        let fft2 = signal2

        // Overlap add method
        let overlap = blockSize - 1
        let convolutionResultSize = signal1.count + signal2.count - overlap
        var convolutionResult = [Float](repeating: 0.0, count: convolutionResultSize)

        for i in stride(from: 0, to: signal1.count, by: blockSize - overlap) {
            // Convolution spectrum
            var convolutionSpectrum = [Complex64](repeating: Complex64(0.0, 0.0), count: blockSize)

            // Convolution spectrum calculation
            for j in i ..< min(i + blockSize, signal1.count) {
                convolutionSpectrum[j - i] += Complex64(fft1[i] * fft2[j], 0.0)
            }

            // Inverse FFT
            let inverseFFT = convolutionSpectrum.map { $0.real }

            // Overlap and add
            for j in 0 ..< inverseFFT.count {
                convolutionResult[i + j] += inverseFFT[j]
            }
        }

        return convolutionResult
    }
    
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
    
    //複素数Complex64をfloatに変換するコード　→ 意味ある？
    func complexToFloatArray(_ complexArray: [Complex64]) -> [Float] {
        var floatArray = [Float](repeating: 0.0, count: complexArray.count * 2)
        
        for (index, complex) in complexArray.enumerated() {
            floatArray[index * 2] = complex.real
            floatArray[index * 2 + 1] = complex.imag
        }
        
        return floatArray
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
    
    // フィルタリングの際にウィンドウを適用
    func applyRectangularWindow(signal: [Float], windowSize: Int) -> [Complex64] {
        if(!windowMode){
            var spectrum = [Complex64]()
            
            for i in stride(from: 0, to: signal.count, by: windowSize) {
                let endIndex = min(i + windowSize, signal.count)
                let windowedSignal = Array(signal[i..<endIndex])
                
                // フィルタリングの際にウィンドウを適用
                let windowedSignalWithRectangularWindow = windowedSignal.map { value in
                    return value * 1.0 // ここで矩形窓を適用 (1.0 は矩形窓の係数)
                }
                
                // 窓関数を適用した信号にFFTを実行
                let fftResult = FFT(signal: windowedSignalWithRectangularWindow)
                
                // FFT結果をspectrumに追加
                spectrum.append(contentsOf: fftResult)
            }
            
            return spectrum
        }else{
            return FFT(signal: signal)
        }
    }
    
    //ピークを見つけるコード　→ 機能してない
    func findPeaks(_ data: [CGFloat]) -> Int? {
        guard !data.isEmpty else {
                return nil // データが空の場合は nil を返すか、エラー処理を追加することができます
            }

            if let maxIndex = data.indices.max(by: { data[$0] < data[$1] }) {
                return maxIndex
            } else {
                return nil // 最大値が見つからない場合は nil を返すか、エラー処理を追加することができます
            }
        }

    //ピークの周辺を抽出するコード　→ 機能してない
    func extractDataAroundPeaks(_ data: [CGFloat], peakIndex: Int, dataPointsCount: Int) -> [CGFloat] {
        let segmentCount = dataPointsCount / 2
        var extractedData = [CGFloat]()
        
        let startIndex = Int(max(0, peakIndex - segmentCount))
        let endIndex = Int(min(data.count - 1, peakIndex + segmentCount))
        
        // ピークの周りのデータを抽出して連結
        if startIndex <= endIndex {
            let segmentData = Array(data[startIndex...endIndex])
            extractedData.append(contentsOf: segmentData)
        }
        
        return extractedData
    }
    
    //ピーク以降を抽出するコード　→ 機能してない
    func extractDataAfterPeak(_ data: [CGFloat], peakIndex: Int, dataPointsCount: Int) -> [CGFloat] {
        var extractedData = [CGFloat]()
        
        let startIndex = peakIndex // ピークの位置から始める
        let endIndex = min(data.count - 1, startIndex + dataPointsCount - 1) // ピークから指定のデータポイント数だけ取得
        
        if startIndex <= endIndex {
            let segmentData = Array(data[startIndex...endIndex])
            extractedData.append(contentsOf: segmentData)
        }
        
        return extractedData
    }
    
    //ピーク以前を抽出するコード　→ 機能してない
    func extractDataAfterPeak2(_ data: [CGFloat], peakIndex: Int, dataPointsCount: Int) -> [CGFloat] {
        var extractedData = [CGFloat]()
            
            // ピークの位置からデータを取得
            let startIndex = peakIndex
            
            // ピークの位置から指定のデータポイント数だけデータを取得（降順で）
            let endIndex = max(0, startIndex - dataPointsCount + 1)
            
            if startIndex >= endIndex {
                // ピークから後ろのデータポイントを降順で抽出
                for i in stride(from: startIndex, through: endIndex, by: -1) {
                    extractedData.append(data[i])
                }
            }
            
            return extractedData
        }

    //畳み込みFFTを時間領域に戻すコード
    func performFFT(on data: [CGFloat]) -> [Double] {
        var realPart = [Double](repeating: 0.0, count: data.count)
        var imaginaryPart = [Double](repeating: 0.0, count: data.count)

        // Convert CGFloat data to Double
        for (index, value) in data.enumerated() {
            realPart[index] = Double(value)
        }

        var splitComplex = DSPDoubleSplitComplex(realp: &realPart, imagp: &imaginaryPart)

        let log2n = vDSP_Length(log2(Double(data.count)))
        let setup = vDSP_create_fftsetupD(log2n, Int32(FFT_RADIX2))
        vDSP_fft_zipD(setup!, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))
        vDSP_destroy_fftsetupD(setup)

        // Calculate magnitudes from real and imaginary parts
        var magnitudes = [Double](repeating: 0.0, count: data.count)
        vDSP_zvmagsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(data.count))

        return magnitudes
    }

}

//グラフを描写するための継承
class GraphView: UIView {
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
