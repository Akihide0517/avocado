//
//  ViewController.swift
//  fftconvolveTest
//
//  Created by 吉田成秀 on 2023/11/07.
//

import UIKit
import AVFoundation
import Accelerate
import DGCharts
import MobileCoreServices

class ViewController: UIViewController, UIDocumentPickerDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate{
    
    /**
     フィールド変数
     - filePath : 音声ファイルの名前
     - music : 音声ファイルを変換した配列
     - reverseMusic : musicを逆配列にしたもの
     - resultConvolution : 畳み込みの結果
     - resultIfftConvolution : ifftの結果
     - chartView : DGChartsのグラフ
     - selectArray : 選択したファイルの[Float]
     - EnvelopeMode : エンベロープするかどうか
     - SetEssEnvelopeMode : 逆ESSエンベロープ固定するかどうか
     - SetZeroPaddingMode : ENV固定時に0.5秒の誤差修正範囲を再生前後に設定するかどうか
     - FileMode : ファイルを選択したかどうか
     - isRecording : レコードしているかどうか
     */
    
    var filePath: String = "extended_sweep_sound"
    var music:[Float] = []
    var reverseMusic:[Float] = []
    var resultConvolution:[Complex64] = []
    var resultIfftConvolution:[Float] = []
    var selectArray:[Float] = []
    var EnvelopeMode:Bool = false
    var SetEssEnvelopeMode:Bool = false
    var SetZeroPaddingMode:Bool = false
    var FileMode:Bool = false
    
    var isRecording = false
    
    var chartView: LineChartView!
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // グラフ表示の事前準備
        chartView = LineChartView()
        chartView.frame = CGRect(x: 20, y: 20, width: 300, height: 200) // Set frame as needed
        view.addSubview(chartView)
        print("Create the LineChartView end")
        
        main()
    }
    
    // MARK: - 音声ファイルを取得し、その逆配列をFFTして畳み込んでグラフにするメソッド
    func main(){
        
        //setter(ミュージックの変換)
        if(FileMode){
            music = selectArray
            reverseMusic = reverseFloatArray(floatArray: selectArray)
            makeEnvelopeForUserFile()
        }else{
            if let floatArray = loadWavAudioFileToCGFloatArray(filePath: filePath) {
                music = floatArray
                reverseMusic = reverseFloatArray(floatArray: floatArray)
                makeEnvelopeForESS()
            } else {
                print("Failed to load audio file")
            }
        }
        print("ミュージックの変換終了 music:",music[24001], music[music.count-24001], music.count, " reverseMusic:", reverseMusic[24001], reverseMusic[reverseMusic.count-24001], reverseMusic.count)

        //gettr(畳み込みの実行と逆フーリエ変換)
        resultConvolution = convolutionFFTBlock(signal1: music, signal2: reverseMusic)//Complex64:周波数領域
        resultIfftConvolution = inverseFFT(complexSignal: resultConvolution)//Float：時間領域
        
        //横軸を周波数に合わせる
        adjustHorizontalAxisToFrequency()
        
        print("畳み込みの実行と逆フーリエ変換終了",resultConvolution[0], resultConvolution.count, resultConvolution[resultConvolution.count-1], resultIfftConvolution[0], resultIfftConvolution.count, resultIfftConvolution[resultIfftConvolution.count-1])
        
        //グラフ化処理(時間)
        drawGraph(signal: resultIfftConvolution.map { Double($0) })
        print("グラフ化処理終了")
        
        //波形の保存
        SetResult(complexResult: resultConvolution, TimeResult: resultIfftConvolution)
        print("Setter Done!")
    }
    
    // MARK: - 以下グラフ作成にまつわるコード群
    func drawGraph(signal: [Double]) {
        // グラフ表示の事前準備
        self.chartView.removeFromSuperview()
        self.chartView = LineChartView()
        self.chartView.frame = CGRect(x: 20, y: 20, width: 300, height: 200) // Set frame as needed
        self.view.addSubview(self.chartView)
        
        // Prepare data for the chart
        var entries: [ChartDataEntry] = []
        for (index, magnitude) in signal.enumerated() {
            let entry = ChartDataEntry(x: Double(index), y: magnitude)
            entries.append(entry)
        }
        
        // Create a data set and a data object for the chart
        let dataSet = LineChartDataSet(entries: entries, label: "時間領域の畳み込み結果(振幅/時間)")
        dataSet.drawCirclesEnabled = false
        
        // Customize the chart appearance (optional)
        self.chartView.xAxis.labelPosition = .bottom
        self.chartView.leftAxis.labelPosition = .insideChart
        self.chartView.rightAxis.enabled = false
        
        // Set the new data for the chart
        let data = LineChartData(dataSet: dataSet)
        self.chartView.data = data
        
        // Notify the chart to update and redraw
        self.chartView.notifyDataSetChanged()
    }
    
    // MARK: - 以下wavを取得し、[Float]に変換するコード群
    
    /**
     wavファイルの名前を指定して[CGFloat]を取得するメソッド
     - parameter String: wavなどの音声ファイルをstringで受け取ります。
     - returns: ファイルを変換した[CGFloat]をconvertCGFloatArrayToFloatArrayで[Float]に変換して返します
    */
    func loadWavAudioFileToCGFloatArray(filePath: String) -> [Float]? {
        guard let wavURL = Bundle.main.url(forResource: filePath, withExtension: "wav") else {
            fatalError("WAVファイルが見つかりません")
        }

        do {
            let audioFile = try AVAudioFile(forReading: wavURL)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            
            // サンプルデータを読み込むためのバッファを作成
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
            
            try audioFile.read(into: buffer!)
            
            return Array(UnsafeBufferPointer(start: buffer!.floatChannelData?[0], count: Int(frameCount)))
        } catch {
            fatalError("WAVファイルの読み込みに失敗しました: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - 以下信号をいじるコード群
    
    /**
     [Float]を逆配列にするメソッド
     - parameter floatArray: [Float]を受け取ります
     - returns: [Float]を逆配列に変換して返します
    */
    func reverseFloatArray(floatArray: [Float]) -> [Float] {
        let reversedArray = Array(floatArray.reversed())
        return reversedArray
    }
    
    /**
     [Float]をエンベロープにするメソッド
     - parameter waveform: 入力
     - parameter samplingRate: サンプリングレート
     - parameter fStart: 開始周波数
     - parameter fEnd: 終了周波数
     - returns: エンベロープに変換して返します
    */
    func generateEnvelope(waveform: [Float], samplingRate: Float, fStart: Float, fEnd: Float) -> [Float] {
        let maxAmplitude = waveform.max() ?? 0.0
        let tMax = Float(waveform.count) / samplingRate

        let scaleFactor = pow(fEnd / fStart, 1.0 / tMax) / tMax

        let envelope = waveform.map { sample in
            return sample * maxAmplitude * scaleFactor
        }

        print("envelope作成完了",envelope[0],envelope[envelope.count-1])
        return envelope
    }
    
    /**
     [Float]の長さを調整するメソッド
     - parameter array: [Float]を受け取ります
     - parameter newSize: 新しい最大lengthを受け取ります
     - returns: [Float]を新しい要素数に変更して返します
    */
    func increaseArraySize(_ array: [Float], to newSize: Int) -> [Float] {
        if newSize < array.count {
            // 新しいサイズが元のサイズ未満の場合、要素を切り詰める
            return Array(array.prefix(newSize))
        } else if newSize > array.count {
            // 新しいサイズが元のサイズより大きい場合、不足分の要素を0.0で埋める
            let additionalSize = newSize - array.count
            let additionalElements = [Float](repeating: 0.0, count: additionalSize)
            return array + additionalElements
        } else {
            // 新しいサイズが元のサイズと同じ場合、変更なし
            print("新しいサイズが元のサイズと同じ",array[24001],array[array.count-24001])
            return array
        }
    }
    
    /**
     [Float]の前後に入力された要素数分の０パディングを前後に施すメソッド
     - parameter array: [Float]を受け取ります
     - parameter count: ０パディングしたいlengthを受け取ります
     - returns: [Float]を新しい要素数に変更して返します
    */
    func extendWithZeros(inputArray: [Float], count: Int) -> [Float] {
        // 前に追記するゼロ要素の配列
        let zerosBefore = [Float](repeating: 0.0, count: count)
        // 後ろに追記するゼロ要素の配列
        let zerosAfter = [Float](repeating: 0.0, count: count)
        
        // 元の配列の前後にゼロ要素を追記して新しい配列を生成
        let extendedArray = zerosBefore + inputArray + zerosAfter
        
        print("要素の前後に０パディング", extendedArray.count)
        return extendedArray
    }
    
    // MARK: - ユーザが”SetEssEnvelopeMode”をオンにした状態でswept_sineからエンベロープを作成するメソッド
    func makeEnvelopeForUserFile(){
        if(EnvelopeMode){
            reverseMusic = generateEnvelope(waveform: reverseMusic, samplingRate: 48000, fStart: 10, fEnd: 24000)
            print("エンベロープになりました")
        }
        
        else if(SetEssEnvelopeMode){
            let ESS = loadWavAudioFileToCGFloatArray(filePath: "swept_sine")
            var size = ESS!.count
            
            if(!SetZeroPaddingMode){
                size += (24000*2)//swept_sineの要素数は24万、虚空0.5sの要素数は2万4千
            }else{
                print("FileMode:size虚空なし")
            }
            
            music = increaseArraySize(music, to: size)
            
            reverseMusic = reverseFloatArray(floatArray: ESS!)
            reverseMusic = generateEnvelope(waveform: reverseMusic, samplingRate: 48000, fStart: 10, fEnd: 24000)
            
            if(!SetZeroPaddingMode){
                reverseMusic = extendWithZeros(inputArray: reverseMusic, count: 24000)
            }
            print("エンベロープ固定")
        }
    }
    
    // MARK: - ユーザが”SetEssEnvelopeMode”をオフにした状態でswept_sineからエンベロープを作成するメソッド
    func makeEnvelopeForESS(){
        if(EnvelopeMode){
            reverseMusic = generateEnvelope(waveform: reverseMusic, samplingRate: 48000, fStart: 10, fEnd: 24000)
            print("エンベロープになりました")
        }
        
        else if(SetEssEnvelopeMode){
            let ESS = loadWavAudioFileToCGFloatArray(filePath: "swept_sine")
            var size = ESS!.count
            
            if(!SetZeroPaddingMode){
                size += (24000*2)//swept_sineの要素数は24万、虚空0.5sの要素数は2万4千
            }else{
                print("size虚空なし")
                if let floatArray2 = loadWavAudioFileToCGFloatArray(filePath: "swept_sine") {
                    music = floatArray2
                }
            }
            
            music = increaseArraySize(music, to: size)
            
            reverseMusic = reverseFloatArray(floatArray: ESS!)
            reverseMusic = generateEnvelope(waveform: reverseMusic, samplingRate: 48000, fStart: 10, fEnd: 24000)
            
            if(!SetZeroPaddingMode){
                reverseMusic = extendWithZeros(inputArray: reverseMusic, count: 24000)
            }
            print("エンベロープ固定")
        }
    }
    
    // MARK: - 周波数軸の波形の横軸のメモリを周波数に合わせるためのメソッド
    func adjustHorizontalAxisToFrequency(){
        if(PeakMode){
            print("切り抜き",Debug2)
            var windowSize:Int = 8192
            if(Debug2){
            windowSize = 4192
            }
            
            let PeakIndex: Int = findPeakIndex(signal: resultIfftConvolution)!//ピークの算出
            var removeElementsResultIfftConvolution =  removeElementsBeforePeak(signal: resultIfftConvolution, peakIndex: PeakIndex)//ピーク以前の削除
            removeElementsResultIfftConvolution = removeElementsAfterIndex(array: removeElementsResultIfftConvolution, count: windowSize)//8192以降の削除
            resultConvolution = FFT(signal: removeElementsResultIfftConvolution)//FFT
            
            resultIfftConvolution = getSurroundingValues(inputArray: resultIfftConvolution, peakIndex: PeakIndex, surroundingCount: 6000)//時間領域のインパルスのピーク周辺の取得
        }
    }
    
    // MARK: - 以下FFTを用いた畳み込みに必要なコード群
    
    /**
     高校速フーリエ変換するメソッド
     - parameter signal: wavなどの音声や波形を[Float]型で受け取ります
     - returns: 自作複素数型である[Complex64]に則って戻り値を設定する必要があります
    */
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
    
    /**
     高校速逆フーリエ変換するメソッド
     - parameter signal: wavなどの音声や波形のFFT結果を[Complex64]型で受け取ります
     - returns: 複素数型である[Complex64]を逆算して[Float]で戻します
    */
    func inverseFFT(complexSignal: [Complex64]) -> [Float] {
        let log2n = vDSP_Length(log2(Float(complexSignal.count)))
        let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)!

        var inputReal = [Float](repeating: 0.0, count: complexSignal.count)
        var inputImag = [Float](repeating: 0.0, count: complexSignal.count)
        var outputReal = [Float](repeating: 0.0, count: complexSignal.count)
        var outputImag = [Float](repeating: 0.0, count: complexSignal.count)

        for i in 0..<complexSignal.count {
            inputReal[i] = complexSignal[i].real
            inputImag[i] = complexSignal[i].imag
        }

        inputReal.withUnsafeMutableBufferPointer { inputRealPtr in
            inputImag.withUnsafeMutableBufferPointer { inputImagPtr in
                outputReal.withUnsafeMutableBufferPointer { outputRealPtr in
                    outputImag.withUnsafeMutableBufferPointer { outputImagPtr in
                        let input = DSPSplitComplex(realp: inputRealPtr.baseAddress!, imagp: inputImagPtr.baseAddress!)
                        var output = DSPSplitComplex(realp: outputRealPtr.baseAddress!, imagp: outputImagPtr.baseAddress!)

                        fft.inverse(input: input, output: &output)
                    }
                }
            }
        }

        var signal = [Float](repeating: 0.0, count: complexSignal.count)

        for i in 0..<complexSignal.count {
            signal[i] = outputReal[i]
        }

        return signal
    }

    /**
     バタフライ演算をするメソッド
     - parameter signal1: wavなどの音声や波形を[Float]型で受け取ります
     - parameter signal2: wavなどの音声や波形を逆向きにしたものを[Float]型で受け取ります
     - returns: 計算の過程でfftを行うため、複素数型である[Complex64]で戻します
    */
    func convolutionFFTBlock(signal1: [Float], signal2: [Float]) -> [Complex64] {
        
        // Calculate the required size for FFT (next power of 2)
        let paddedSize = 1 << Int(ceil(log2(Double(signal1.count + signal2.count - 1))))
        
        // Perform FFT on the original signals
        let fft1 = FFT(signal: signal1)
        let fft2 = FFT(signal: signal2)

        // Zero-pad the FFT results to the desired size
        var paddedFFT1 = fft1 + [Complex64](repeating: Complex64(0.0, 0.0), count: paddedSize - fft1.count)
        var paddedFFT2 = fft2 + [Complex64](repeating: Complex64(0.0, 0.0), count: paddedSize - fft2.count)

        // Convolution spectrum
        var convolutionSpectrum = [Complex64](repeating: Complex64(0.0, 0.0), count: paddedSize)
        
        // Convolution spectrum calculation
        for i in 0..<paddedSize {
            convolutionSpectrum[i] = Complex64(paddedFFT1[i].real * paddedFFT2[i].real - paddedFFT1[i].imag * paddedFFT2[i].imag, paddedFFT1[i].real * paddedFFT2[i].imag + paddedFFT1[i].imag * paddedFFT2[i].real)
        }

        // Inverse FFT
        let inverseFFT = convolutionSpectrum.map { $0 }

        return inverseFFT
    }
    
    /**
     ピークを検出するメソッド
     - parameter signal: convolutionFFTBlockのsignalを[Float]型で受け取ります
     - returns: 配列の絶対値の最大値のindexを返します
    */
    func findPeakIndex(signal: [Float]) -> Int? {
        guard !signal.isEmpty else { return nil }

        var maxAbsValue: Float = abs(signal[0])
        var peakIndex: Int = 0

        for (index, value) in signal.enumerated() {
            let absValue = abs(value)
            if absValue > maxAbsValue {
                maxAbsValue = absValue
                peakIndex = index
            }
        }

        return peakIndex
    }
    
    /**
     ピーク以前を削除するメソッド
     - parameter signal: convolutionFFTBlockのsignalを[Float]型で受け取ります
     - parameter peakIndex: findPeakIndexの結果を受け取ります
     - returns: 変換結果を返します
    */
    func removeElementsBeforePeak(signal: [Float], peakIndex: Int) -> [Float] {
        guard peakIndex >= 0 && peakIndex < signal.count else { return [] }
        
        let truncatedSignal = Array(signal.suffix(from: peakIndex))
        return truncatedSignal
    }
    
    /**
     指定した数以降を削除するメソッド
     - parameter array: convolutionFFTBlockのsignalを[Float]型で受け取ります
     - parameter index: 確保したい要素数
     - returns: 変換結果を返します
    */
    func removeElementsAfterIndex<T>(array: [T], count: Int) -> [T] {
        guard count >= 0 && count <= array.count else {
            // Handle invalid count value (negative or greater than array length)
            return array
        }

        return Array(array.prefix(count))
    }
    
    /**
     指定した数の指定した分の入力配列の周辺を取得するメソッド
     - parameter inputArray: 時間領域の信号を受け取ります
     - parameter peakIndex: 周辺の配列を取得するための、中心のインデックス
     - parameter surroundingCount: peakIndexに対してその周辺から取得したい数を指定する
     - returns: 変換結果を返します
    */
    func getSurroundingValues(inputArray: [Float], peakIndex: Int, surroundingCount: Int) -> [Float] {
        // ピークの位置を確認し、範囲を決定します
        let lowerBound = max(0, peakIndex - surroundingCount)
        let upperBound = min(inputArray.count - 1, peakIndex + surroundingCount)
        
        // 範囲内の要素を取得します
        let surroundingValues = Array(inputArray[lowerBound...upperBound])
        
        return surroundingValues
    }
    
    // MARK: - Setter
    
    /**
     結果を静的フィールドに保存するメソッド
     - parameter complexResult: 周波数領域の結果を受け取ります
     - parameter TimeResult: 時間領域の結果を受け取ります
    */
    func SetResult(complexResult: [Complex64], TimeResult: [Float]){
        ComplexResultConvolution = complexResult
        TimeResultConvolution = TimeResult
    }

    // MARK: - 以下@IBAction
    
    //エンベロープにするかどうか
    @IBAction func switchValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            EnvelopeMode = true
        } else {
            // UISwitchがオフの場合
            EnvelopeMode = false
        }
    }
    
    //ESSエンベロープ固定にするかどうか
    @IBAction func switchValueChanged2(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            SetEssEnvelopeMode = true
        } else {
            // UISwitchがオフの場合
            SetEssEnvelopeMode = false
        }
    }
    
    //ESSエンベロープ固定にするかどうか
    @IBAction func switchValueChanged3(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            SetZeroPaddingMode = true
        } else {
            // UISwitchがオフの場合
            SetZeroPaddingMode = false
        }
    }
    
    //出力をピークから8192点で切り抜くかどうか
    @IBAction func switchValueChanged4(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            PeakMode = true
        } else {
            // UISwitchがオフの場合
            PeakMode = false
        }
    }
    
    //ESS を流しながら録音
    @IBAction func playMusicButtonAction(_ sender: Any) {
        FileMode = true
        
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            // マイクへのアクセス許可がまだリクエストされていない場合
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    // マイクへのアクセスが許可された場合の処理
                    self.startRecording()
                    self.playMusicFile()
                    
                    var delayInSeconds: Double = 6.0
                    
                    if(self.SetZeroPaddingMode){
                        print("delayInSeconds虚空なし")
                        delayInSeconds = 5.0
                    }
                    
                    let delayQueue = DispatchQueue.global(qos: .userInitiated)

                    delayQueue.asyncAfter(deadline: .now() + delayInSeconds) {
                        // 5秒後に実行したいコードをここに書きます
                        print(delayInSeconds,"秒後に実行されました")
                        self.dilayStopMusic()
                    }
                } else {
                    // マイクへのアクセスが拒否された場合の処理
                }
            }
        } else {
            // すでにマイクへのアクセス許可が得られている場合
            self.startRecording()
            self.playMusicFile()
            
            var delayInSeconds: Double = 6.0
            
            if(self.SetZeroPaddingMode){
                print("delayInSeconds虚空なし")
                delayInSeconds = 5.0
            }
            
            let delayQueue = DispatchQueue.global(qos: .userInitiated)

            delayQueue.asyncAfter(deadline: .now() + delayInSeconds) {
                // 5秒後に実行したいコードをここに書きます
                print(delayInSeconds,"秒後に実行されました")
                self.dilayStopMusic()
            }
        }
    }
    
    //遅延して音楽停止
    func dilayStopMusic(){
        stopRecording()
        stopMusicFile()
    }
    
    //音楽停止
    func stopMusicFile() {
        
        var Resource = ""
        if(!SetZeroPaddingMode){
            Resource = "extended_sweep_sound"
        }else{
            print("stopMusicFile虚空なし")
            Resource = "swept_sine"
        }
        
        guard let url = Bundle.main.url(forResource: Resource, withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.stop()
        } catch {
            print("Failed to set up audio player: \(error)")
        }
    }
    
    //音楽再生
    func playMusicFile() {
        
        var Resource = ""
        if(!SetZeroPaddingMode){
            Resource = "extended_sweep_sound"
        }else{
            print("playMusicFile虚空なし")
            Resource = "swept_sine"
        }
        
        guard let url = Bundle.main.url(forResource: Resource, withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.play()
        } catch {
            print("Failed to set up audio player: \(error)")
        }
    }
    
    //録音開始
    func startRecording() {
        if !isRecording {
            let audioSettings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48000.0,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ] as [String: Any]

            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to set up audio session: \(error)")
            }

            do {
                audioRecorder = try AVAudioRecorder(url: getDocumentsDirectory().appendingPathComponent("recording.m4a"), settings: audioSettings)
                audioRecorder.delegate = self
                audioRecorder.prepareToRecord()
                audioRecorder.record()
                isRecording = true
            } catch {
                print("Failed to set up audio recorder: \(error)")
            }
        }
    }
    
    //URL取得
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    //録音停止
    func stopRecording() {
        if isRecording {
            audioRecorder.stop()
            isRecording = false
        }
        selectArray = getWaveformFromAudioFile()!
    }
    
    //録音データの取得
    func getWaveformFromAudioFile() -> [Float]? {
        let audioFileURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")

        if FileManager.default.fileExists(atPath: audioFileURL.path) {
            // ファイルが存在する場合の処理
            do {
                let audioFile = try AVAudioFile(forReading: audioFileURL)
                
                // 以下のコードを続けて波形データを取得する
            } catch {
                print("Failed to open audio file: \(error)")
            }
        } else {
            print("Audio file not found")
        }

        
        do {
            let audioFile = try AVAudioFile(forReading: audioFileURL)
            
            // サンプル数を取得
            let totalSamples = audioFile.length
            
            // 波形データを取得
            let format = audioFile.processingFormat
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples))
            
            try audioFile.read(into: buffer!)
            
            // データを [Float] に変換
            let floatArray = Array(UnsafeBufferPointer(start: buffer?.floatChannelData![0], count: Int(buffer!.frameLength)))
            
            return floatArray
        } catch {
            print("Failed to get waveform data: \(error)")
            return nil
        }
    }
    
    //ファイルの選択
    @IBAction func SelectFile(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false // 複数のファイルを選択する場合はtrueに設定

        present(documentPicker, animated: true, completion: nil)
        FileMode = true
    }

    //URLの取得
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let selectedFileURL = urls.first {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first // ドキュメントディレクトリを取得

            var destinationURL = documentsDirectory?.appendingPathComponent(selectedFileURL.lastPathComponent)

            if fileManager.fileExists(atPath: destinationURL!.path) {
                // 既に同名のファイルが存在する場合、新しい名前を生成するなどの対処を行います
                destinationURL = generateUniqueDestinationURL(for: destinationURL!)
            }

            do {
                // サムネイルの生成を試みる
                try fileManager.copyItem(at: selectedFileURL, to: destinationURL!)

                // サムネイルを保存
                let thumbnailImage = generateThumbnail(for: destinationURL!)
                let thumbnailData = thumbnailImage.pngData()
                try fileManager.createFile(atPath: destinationURL!.appendingPathComponent("thumbnail.png").path, contents: thumbnailData)

                // ファイルを[Float]に変換して保存
                let data = try Data(contentsOf: destinationURL!)
                let samples = data.withUnsafeBytes { (bytes: UnsafePointer<Float>) -> [Float] in
                    var samples = [Float](repeating: 0.0, count: data.count / MemoryLayout<Float>.size)
                    memcpy(&samples, bytes, samples.count * MemoryLayout<Float>.size)
                    return samples
                }

                // 変換した[Float]を保存
                selectArray = samples
                print("Selected file converted to [Float]")
            } catch {
                // エラーが発生した場合の処理
                print("Error: \(error)")
            }
        }
    }

    // サムネイルを生成するメソッド
    func generateThumbnail(for fileURL: URL) -> UIImage {
        // 仮のサムネイル画像のサイズ
        let thumbnailSize = CGSize(width: 100, height: 100)
        
        // グラフィックスコンテキストを作成
        UIGraphicsBeginImageContext(thumbnailSize)
        
        // サムネイルの背景色
        let backgroundColor = UIColor.blue
        
        // 背景色を描画
        backgroundColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: thumbnailSize))
        
        // ここでサムネイルに他の要素（テキスト、画像など）を追加できます
        // 例: ファイル名を表示
        let fileName = fileURL.lastPathComponent as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white
        ]
        let textRect = CGRect(x: 10, y: 10, width: thumbnailSize.width - 20, height: 30)
        fileName.draw(in: textRect, withAttributes: textAttributes)
        
        // グラフィックスコンテキストから画像を取得
        let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // グラフィックスコンテキストを終了
        UIGraphicsEndImageContext()
        
        return thumbnailImage ?? UIImage() // サムネイル画像を返します
    }

    // 重複しない新しいファイル名を生成する関数
    func generateUniqueDestinationURL(for destinationURL: URL) -> URL {
        var newName = "new_" + destinationURL.lastPathComponent
        var newURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newName)

        while FileManager.default.fileExists(atPath: newURL.path) {
            newName = "new_" + newName
            newURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newName)
        }

        return newURL
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // キャンセルボタンが押された場合の処理
    }
    
    //再描画
    @IBAction func Retry(_ sender: Any) {
        main()
    }
}

