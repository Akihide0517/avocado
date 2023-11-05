//
//  AudioController.swift
//  audioavocado -Test
//
//  Created by 吉田成秀 on 2023/10/16.

import Foundation
import AVFoundation
import UIKit
import Dispatch
import DGCharts

class AudioController:  UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate{
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    var isRecording = false
    
    // チャート
    var chartView: LineChartView!
    // チャートデータ
    var lineDataSet: LineChartDataSet!
    
    @IBOutlet weak var ReverseWaveText: UITextView!
    @IBOutlet weak var WaveText: UITextView!//デバック用のm4a出力確認text
    @IBOutlet weak var volumeStepper: UIStepper?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        wave = []
        reversewave = []
        Level = false
        peakMode = true
        peakDir = false
        graphMode = true
        IFFTMode = true
        blockSize = 2
        threads = 0
        selfMode = false
        envelope_reversedMode = false
        floatArray = []

        Processing = 0
        convolutionMode1 = []
        convolutionMode2 = []
        FFTProcessing = 0
        debugGraphMode = 0
        convolutionMode = 0
        convolutionModeA = 0
        convolutionModeB = 0
        reversefloatArray = []
        convolutionFFTSelect = false

        windowSize = 1024
        nyquist = 65000
        
        
        setupAudioSession()
        
        selfMode = false
        
        guard let wavURL = Bundle.main.url(forResource: "swept_sine", withExtension: "wav") else {
            fatalError("WAVファイルが見つかりません")
        }

        do {
            let audioFile = try AVAudioFile(forReading: wavURL)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            
            // サンプルデータを読み込むためのバッファを作成
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
            
            try audioFile.read(into: buffer!)
            
            // サンプルデータを[CGFloat]に変換
            floatArray = Array(UnsafeBufferPointer(start: buffer!.floatChannelData?[0], count: Int(frameCount)))
            reversewave = reverseCGFloatArray(floatArray.map { CGFloat($0) })
        } catch {
            fatalError("WAVファイルの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
    
    func drawChart(y: [Double]) {
        if(chartView != nil){
            chartView.removeFromSuperview()
        }
        
        // チャートビューのサイズと位置を定義
        self.chartView = LineChartView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200))
        
        // チャートに渡す用の配列を定義
        var dataEntries: [ChartDataEntry] = []
        
        // Y軸のデータリストからインデックスと値を取得し配列に格納
        for (index, value) in y.enumerated() {
            // X軸は配列のインデックス番号
            let dataEntry = ChartDataEntry(x: Double(index), y: value)
            dataEntries.append(dataEntry)
        }

        var entries: [ChartDataEntry] = []
        for (index, magnitude) in y.enumerated() {
            let entry = ChartDataEntry(x: Double(index), y: magnitude)
            entries.append(entry)
        }
        
        // 折れ線グラフ用のデータセット labelはデータの説明ラベル
        lineDataSet = LineChartDataSet(entries: entries, label: "")
        // グラフに反映
        chartView.data = LineChartData(dataSet: lineDataSet)

         // MARK: - ここからグラフデザイン設定
        
        chartView.xAxis.labelPosition = .bottom
        chartView.rightAxis.enabled = false
        lineDataSet.drawCirclesEnabled = false

        self.view.addSubview(self.chartView)
    }
    
    @IBAction func volumeStepperValueChanged(_ sender: UIStepper) {
        let newVolume = Float(sender.value) // ステッパーの値を取得
        audioPlayer?.volume = newVolume // AVAudioPlayerの音量を設定
    }
    
    @IBAction func Test2(_ sender: Any) {
    }
    
    @IBOutlet weak var peakModeSwitch: UISwitch!

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            peakMode = true
        } else {
            // UISwitchがオフの場合
            peakMode = false
        }
    }
    
    @IBOutlet weak var peakDirSwitch: UISwitch!

    @IBAction func peakDirswitchValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            print("DirOn")
            peakDir = true
        } else {
            // UISwitchがオフの場合
            print("DirOFF")
            peakDir = false
        }
    }
    
    @IBOutlet weak var graphModeSwitch: UISwitch!

    @IBAction func graphModeValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            graphMode = true
        } else {
            // UISwitchがオフの場合
            graphMode = false
        }
    }
    
    @IBOutlet weak var IFFTModeSwitch: UISwitch!

    @IBAction func IFFTModeValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            IFFTMode = true
        } else {
            // UISwitchがオフの場合
            IFFTMode = false
        }
    }
    
    @IBOutlet weak var IFFTModeSwitch2: UISwitch!

    @IBAction func IFFTModeValueChanged2(_ sender: UISwitch) {
        if sender.isOn {
            // UISwitchがオンの場合
            IFFTMode = true
        } else {
            IFFTMode = false
            // UISwitchがオフの場合
        }
    }
    
    @IBAction func playMusicButtonAction(_ sender: Any) {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            // マイクへのアクセス許可がまだリクエストされていない場合
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    // マイクへのアクセスが許可された場合の処理
                    self.startRecording()
                    self.playMusicFile()
                    
                    let delayInSeconds: Double = 5.0
                    let delayQueue = DispatchQueue.global(qos: .userInitiated)

                    delayQueue.asyncAfter(deadline: .now() + delayInSeconds) {
                        // 5秒後に実行したいコードをここに書きます
                        print("5秒後に実行されました")
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
            
            let delayInSeconds: Double = 5.0
            let delayQueue = DispatchQueue.global(qos: .userInitiated)

            delayQueue.asyncAfter(deadline: .now() + delayInSeconds) {
                // 5秒後に実行したいコードをここに書きます
                print("5秒後に実行されました")
                self.dilayStopMusic()
            }
        }
    }
    
    @IBAction func saveSweep(_ sender: Any) {
        guard let wavURL = Bundle.main.url(forResource: "swept_sine", withExtension: "wav") else {
            fatalError("WAVファイルが見つかりません")
        }

        do {
            let audioFile = try AVAudioFile(forReading: wavURL)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            
            // サンプルデータを読み込むためのバッファを作成
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
            
            try audioFile.read(into: buffer!)
            
            // サンプルデータを[Float]に変換
            floatArray = padToNextPowerOfTwo(signal: Array(UnsafeBufferPointer(start: buffer!.floatChannelData?[0], count: Int(frameCount))))
            print("floatArray in swept_sine")
            
            // ここでfloatArrayを使用して必要な処理を行います
            if(IFFTMode){
                reversewave = reverseCGFloatArray(floatArray.map { CGFloat($0) })
                reversefloatArray = reverseCGFloatArray(floatArray.map { CGFloat($0) })
            }else{
                reversewave = floatArray.map { CGFloat($0) }
            }
            
            if(IFFTMode){
                // 使用例
                if let envelopedFloatArray = loadWavFileAndCreateEnvelope(fileName: "swept_sine", fileExtension: "wav", envelopeDuration: 5.0) {
                    reversewave = envelopedFloatArray
                    print("WAVファイルを逆順に変更し、エンベロープを作成しました。")
                } else {
                    print("WAVファイルの変換に失敗しました。")
                }
            }
            print("reversewave.count:",reversewave.count,"wave.count:",wave.count)
            convolutionMode2 = reversewave
            
            wave = resizeArray(wave, toNewSize: 240000)
            
            if reversewave.count < wave.count {
                // reversewaveがwaveより短い場合、waveの長さに合わせてデータを補填
                let diffCount = wave.count - reversewave.count
                let paddingData: [CGFloat] = Array(repeating: 0.0, count: diffCount)
                reversewave.append(contentsOf: paddingData)
                print("reversewaveが短い")
            } else if reversewave.count > wave.count {
                // reversewaveがwaveより長い場合、余分なデータを削除
                //reversewave.removeLast(reversewave.count - wave.count)
                print("reversewaveが長い")
            }
            print("補充したwave.count:",wave.count)
            
        } catch {
            fatalError("WAVファイルの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
    
    func resizeArray(_ array: [CGFloat], toNewSize newSize: Int) -> [CGFloat] {
        if newSize <= 0 {
            // 新しいサイズが無効な場合、エラー処理などを行う
            // ここでエラーメッセージを表示またはエラーを処理する
            return array // エラーの場合は入力の配列をそのまま返す
        }

        var newArray = array // 入力の配列をコピー
        let currentSize = newArray.count

        if newSize > currentSize {
            // 新しいサイズが大きい場合、不足分をゼロで埋める
            newArray += [CGFloat](repeating: 0.0, count: newSize - currentSize)
        } else if newSize < currentSize {
            // 新しいサイズが小さい場合、不要な要素を削除
            newArray.removeSubrange(newSize..<currentSize)
        }

        return newArray
    }
    
    func padToNextPowerOfTwo(signal: [Float]) -> [Float] {
        let originalLength = signal.count
        
        // 2のべき乗に切り上げる
        let nextPowerOfTwo = Int(ceil(log2(Double(originalLength))))
        
        // パディング後の長さを計算
        let paddedLength = 1 << nextPowerOfTwo
        
        // パディングを行う
        var paddedSignal = signal
        paddedSignal.append(contentsOf: [Float](repeating: 0.0, count: paddedLength - originalLength))
        
        return paddedSignal
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

                print(envelopeArray.count)
                // エンベロープをWAVデータの長さに合わせる
                while envelopeArray.count < reversedFloatArray.count {
                    envelopeArray.append(0.0)
                }
                print(envelopeArray.count)

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
    
    @IBAction func ValueChanged(_ sender: UISegmentedControl) {
            switch sender.selectedSegmentIndex {
            case 0:
                blockSize = 2
            case 1:
                blockSize = 4
            case 2:
                blockSize = 8
            case 3:
                blockSize = 16
            default:
                print("存在しない番号")
            }
        }
    
    @IBAction func ValueChanged2(_ sender: UISegmentedControl) {
            switch sender.selectedSegmentIndex {
            case 0:
                threads = 0
            case 1:
                threads = 850
            case 2:
                threads = 100
            default:
                print("存在しない番号")
            }
        }
    
    @IBAction func makeWavegraphButtonAction(_ sender: Any) {
        // 波形データを取得して表示
        if let waveform = getWaveformFromAudioFile() {
            let reversedData = reverseCGFloatArray(waveform)
            //print("waveform:\(waveform)")
            //print("reversedData:\(reversedData)")
            
            //WaveText.text = "\(waveform)"//デバック用のm4a出力確認text
            //ReverseWaveText.text = "\(reversedData)"
            
            //継承
            wave = waveform
            reversewave = reversedData
            
            //let waveformView = WaveformView()
            //waveformView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            //self.view.addSubview(waveformView)
            //waveformView.waveform = waveform
            
            drawChart(y: wave.map { Double($0) })
            
        } else {
            print("Failed to retrieve waveform data")
        }
        reverseAndSaveAudio()
    }
    
    @IBAction func startPlaybackButtonAction(_ sender: Any) {
        startPlayback()
    }
    
    func dilayStopMusic(){
        stopRecording()
        stopPlayback()
        stopMusicFile()
    }
    
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
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
    
    func reverseAndSaveAudio() {
        //逆再生したいなー
    }
    
    func stopRecording() {
        if isRecording {
            audioRecorder.stop()
            isRecording = false
        }
    }
    
    func startPlayback() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: getDocumentsDirectory().appendingPathComponent("recording.m4a"))
            audioPlayer.delegate = self
            audioPlayer.play()
        } catch {
            print("Failed to set up audio player: \(error)")
        }
    }
    
    func stopPlayback() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: getDocumentsDirectory().appendingPathComponent("recording.m4a"))
            audioPlayer.delegate = self
            audioPlayer.stop()
        } catch {
            print("Failed to set up audio player: \(error)")
        }
    }
    
    func playMusicFile() {
        guard let url = Bundle.main.url(forResource: "swept_sine", withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.play()
        } catch {
            print("Failed to set up audio player: \(error)")
        }
    }
    
    func stopMusicFile() {
        guard let url = Bundle.main.url(forResource: "swept_sine", withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.stop()
        } catch {
            print("Failed to set up audio player: \(error)")
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func getWaveformFromAudioFile() -> [CGFloat]? {
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
            
            // データを [CGFloat] に変換
            let floatArray = Array(UnsafeBufferPointer(start: buffer?.floatChannelData![0], count: Int(buffer!.frameLength)))
            
            let cgFloatArray = floatArray.map { CGFloat($0) }
            
            return cgFloatArray
        } catch {
            print("Failed to get waveform data: \(error)")
            return nil
        }
    }
    
    func reverseCGFloatArray(_ inputArray: [CGFloat]) -> [CGFloat] {
        let reversedArray = inputArray.reversed()
        return Array(reversedArray)
    }

}

//waveグラフ化
class WaveformView: UIView {
    var waveform: [CGFloat] = [] // 波形データを保持するプロパティ（振幅と時間の積分）

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        context.setStrokeColor(UIColor.blue.cgColor)
        context.setLineWidth(2.0)

        let path = UIBezierPath()

        let width = rect.size.width
        let height = rect.size.height

        for (index, amplitude) in waveform.enumerated() {
            let x = CGFloat(index) / CGFloat(waveform.count) * width
            let y = (1 - amplitude) * height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.addPath(path.cgPath)
        context.strokePath()
    }
}
