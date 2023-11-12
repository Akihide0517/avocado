//
//  GraphViewController.swift
//  fftconvolveTest
//
//  Created by 吉田成秀 on 2023/11/09.
//

import Foundation
import UIKit
import Accelerate
import DGCharts

class GraphViewController: UIViewController{
    var chartView1: LineChartView!
    var chartView2: LineChartView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // グラフ表示の事前準備1
        chartView1 = LineChartView()
        chartView1.frame = CGRect(x: 20, y: 20, width: 300, height: 200) // Set frame as needed
        view.addSubview(chartView1)
        print("Create the chartView1 end")
        
        drawTimeGraph(signal: TimeResultConvolution.map{Double($0)}, chartView: chartView1)
        
        // グラフ表示の事前準備2
        chartView2 = LineChartView()
        chartView2.frame = CGRect(x: 20, y: 220, width: 300, height: 200) // Set frame as needed
        view.addSubview(chartView2)
        print("Create the chartView2 end")
        
        drawComplexGraph(signal: ComplexResultConvolution, chartView: chartView2)
    }
    
    // MARK: - 以下グラフ作成にまつわるコード群
    
    /** 時間軸専用 */
    func drawTimeGraph(signal: [Double], chartView: LineChartView!) {
        var DGChartView: LineChartView = chartView
        
        // グラフ表示の事前準備
        DGChartView.removeFromSuperview()
        DGChartView = LineChartView()
        DGChartView.frame = CGRect(x: 20, y: 20, width: 300, height: 200) // Set frame as needed
        self.view.addSubview(DGChartView)
        
        // Prepare data for the chart
        var entries: [ChartDataEntry] = []
        for (index, magnitude) in signal.enumerated() {
            let entry = ChartDataEntry(x: Double(index), y: magnitude)
            entries.append(entry)
        }
        
        // Create a data set and a data object for the chart
        let dataSet = LineChartDataSet(entries: entries, label: "時間領域(振幅/時間)")
        dataSet.drawCirclesEnabled = false
        
        // Customize the chart appearance (optional)
        DGChartView.xAxis.labelPosition = .bottom
        DGChartView.rightAxis.enabled = false
        
        // Set the new data for the chart
        let data = LineChartData(dataSet: dataSet)
        DGChartView.data = data
        
        // Notify the chart to update and redraw
        DGChartView.notifyDataSetChanged()
    }
    
    /** 周波数軸でスペクトルを描画 */
    func drawComplexGraph(signal: [Complex64], chartView: LineChartView!) {
        var DGChartView: LineChartView = chartView

        // フーリエ変換の結果から周波数スペクトルを計算
        let numDataPoints = signal.count
        let samplingRate: Float = 48000.0

        // x軸: 周波数 (Hz) を計算
        let frequencyValues = (0..<numDataPoints).map { Float($0) * samplingRate / Float(numDataPoints) }

        // y軸: スペクトルの振幅を計算
        let magnitudeValues = signal.map { sqrt($0.real * $0.real + $0.imag * $0.imag) }

        // グラフ表示の事前準備
        DGChartView.removeFromSuperview()
        DGChartView = LineChartView()
        DGChartView.frame = CGRect(x: 20, y: 220, width: 300, height: 200) // 必要に応じてフレームを設定
        self.view.addSubview(DGChartView)

        // チャート用のデータエントリーを作成
        var entries: [ChartDataEntry] = []
        
        print(Debug1)
        if(!Debug1){
            for i in 0..<numDataPoints {
                let entry = ChartDataEntry(x: Double(frequencyValues[i]), y: Double(magnitudeValues[i]))
                entries.append(entry)
            }
        }else{
            for i in 0..<numDataPoints {
                let entry = ChartDataEntry(x: Double(i), y: Double(magnitudeValues[i]))
                entries.append(entry)
            }
        }

        // チャートデータセットとデータオブジェクトを作成
        let dataSet = LineChartDataSet(entries: entries, label: "周波数領域(振幅/周波数)")
        dataSet.drawCirclesEnabled = false

        // チャートの外観をカスタマイズ（オプション）
        DGChartView.xAxis.labelPosition = .bottom
        DGChartView.rightAxis.enabled = false

        // チャートのデータを設定
        let data = LineChartData(dataSet: dataSet)
        DGChartView.data = data

        // チャートを更新および再描画
        DGChartView.notifyDataSetChanged()
    }
    
    //正解データ登録
    @IBAction func TrueDataButton(_ sender: Any) {
        SaveTrueData = TimeResultConvolution
    }
    
    //不正解データ登録
    @IBAction func FalseDataButton(_ sender: Any) {
        SaveFalseData = TimeResultConvolution
    }
    
    //データポイントの登録
    @IBAction func SetDataPointButton(_ sender: Any) {
        SaveDataPoint = TimeResultConvolution
    }
}

extension Array where Element == Complex64 {

    /// 実部を取り出す
    var real: [Float] {
        return map { $0.real }
    }

    /// 虚部を取り出す
    var imag: [Float] {
        return map { $0.imag }
    }
}
