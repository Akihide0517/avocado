#!/usr/bin/env python3
import pickle
import pandas as pd
import webbrowser
import sys
from flask import Flask, render_template, url_for
from datetime import datetime
import cgi
from PIL import Image, ImageDraw, ImageFont
import os
import html
import json
import numpy as np
from scipy.io import wavfile
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from mpl_toolkits.mplot3d import Axes3D
import random
import firebase_admin
from firebase_admin import credentials, firestore
import subprocess

print("Content-Type: text/html\n")
print()
pca = PCA(n_components=3)

# Firebase Admin SDKを初期化
# ホームディレクトリのパスを取得
cred = credentials.Certificate("/var/www/hac-it-ai-gcp-sweptsine-firebase-adminsdk-3wkiy-6dd823ffed.json")
firebase_admin.initialize_app(cred)

# Firestoreのインスタンスを作成
db = firestore.client()

# 保存先ディレクトリ
save_directory = "/save"
save_directory2 = "/save2"
png_filename = "/"

# 保存ディレクトリが存在しない場合、作成
if not os.path.exists(save_directory):
    os.makedirs(save_directory)

# フォームからデータを取得
form = cgi.FieldStorage()
input_text = html.escape(form.getvalue('input_text', 'Hello from Python!'))  # サニタイズ
selected_collections = html.escape(form.getvalue('selected_collections', ''))  # サニタイズ

# input_textを分割して最初の要素を取得
plase = input_text
first_collection_name = plase

if first_collection_name:
    # コレクションを取得
    collection_ref = db.collection(first_collection_name)
    docs = collection_ref.stream()

    # 保存用の辞書を作成
    collection_data = {}

    for doc in docs:
        # ドキュメント内の 'floatArray' フィールドを取得
        doc_data = doc.to_dict()
        if 'floatArray' in doc_data:
            # signal1, signal2, ... として辞書に追加
            collection_data[doc.id] = doc_data['floatArray']

    # 結果をJSONファイルとして保存
    json_file_path = os.path.join(save_directory2, f"{first_collection_name}.json")
    with open(json_file_path, 'w', encoding='utf-8') as json_file:
        json.dump(collection_data, json_file, ensure_ascii=False, indent=4)

    #print(f"Data from collection '{first_collection_name}' has been saved to {json_file_path}")
else:
    print("No collection name provided in input_text.")

# selected_collectionsを分割してplaseリストに格納
plase = [item.strip() for item in selected_collections.split(",") if item.strip()]

# 各コレクションを処理
for collection_name in plase:
    # コレクションを取得
    collection_ref = db.collection(collection_name)
    docs = collection_ref.stream()

    # 保存用の辞書を作成
    collection_data = {}

    for doc in docs:
        # ドキュメント内の 'floatArray' フィールドを取得
        doc_data = doc.to_dict()
        if 'floatArray' in doc_data:
            # signal1, signal2, ... として辞書に追加
            collection_data[doc.id] = doc_data['floatArray']

    # 結果をJSONファイルとして保存
    json_file_path = os.path.join(save_directory, f"{collection_name}.json")
    with open(json_file_path, 'w', encoding='utf-8') as json_file:
        json.dump(collection_data, json_file, ensure_ascii=False, indent=4)

    #print(f"Data from collection '{collection_name}' has been saved to {json_file_path}")

# file_namesを初期化
file_names = []

# saveディレクトリ内のファイルを取得
for file_name in os.listdir(save_directory):
    if file_name.endswith(".json"):  # JSONファイルのみを対象
        file_path = os.path.join(save_directory, file_name)
        file_names.append(file_path)

# JSONファイルを読み込み、結果を格納する関数
def load_json_files(file_names):
    result_dict = {}
    #print("1")
    for file_name in file_names:
        #print("+")
        with open(file_name, 'r') as file:
            data = json.load(file)
        result_dict[file_name] = data
    #print("2")
    return result_dict

# エンベロープ生成関数
def generate_envelope(waveform, sampling_rate, f_start, f_end):
    waveform = waveform[::-1]  # 波形を逆順に
    max_amplitude = np.max(waveform) if len(waveform) > 0 else 0.0
    t_max = len(waveform) / sampling_rate
    scale_factor = pow(f_end / f_start, 1.0 / t_max) / t_max
    envelope = waveform * max_amplitude * scale_factor
    envelope = np.pad(envelope, (24000, 24000), mode='constant')  # 24000個のゼロパディング
    return envelope

# FFT処理を行う関数
def process_signals(json_data, env, sample_rate):
    FFT_list = []
    dates = []
    signal_names = []

    for date, data in json_data.items():
        if isinstance(data, dict):
            for signal_name, signal_data in data.items():
                # signal_dataが空の場合はスキップ
                if len(signal_data) == 0:
                    #print(f"Warning: {signal_name} on {date} has no data.")
                    continue

                max_value = np.max(np.abs(signal_data))

                # 最大値がゼロの場合はスキップ（ゼロ除算を防ぐ）
                if max_value == 0:
                    #print(f"Warning: {signal_name} on {date} has a max value of 0.")
                    continue

                normalized_signal = signal_data / max_value
                abs_max_index = np.argmax(np.abs(normalized_signal))
                cropped_data = normalized_signal[abs_max_index: abs_max_index + 8192]

                # 畳み込み処理
                convolved_signal = np.convolve(cropped_data, env, mode='same')

                # FFTを実行し、結果を保存
                fft_result = np.fft.fft(convolved_signal)
                fft_result_quarter = np.abs(fft_result[:len(fft_result) // 4])
                
                FFT_list.append(fft_result_quarter)
                dates.append(date)
                signal_names.append(signal_name)

                #print(f"Processed {signal_name} on {date}, FFT list length: {len(FFT_list)}")

    return FFT_list, dates, signal_names

def RE_perform_pca_and_plot(FFT_list, dates, signal_names, latest_pca_result):
    #print(signal_names)

    # FFT_listの形状を確認
    #print("FFT_list shape:", np.array(FFT_list).shape)
    # datesがリストの場合、NumPy配列に変換
    #dates = np.array(dates)
    #print("dates shape:", dates.shape)  # これで次元を確認できる

    matrix = np.array(FFT_list)
    # データの分散がゼロの行を除去
    #non_zero_variance_mask = np.var(matrix, axis=1) > 0
    #if not np.any(non_zero_variance_mask):
    #    raise ValueError("すべてのデータ行の分散がゼロです。")
    #matrix = matrix[non_zero_variance_mask]

    non_zero_variance_mask = np.var(matrix, axis=1) > 0
    matrix = matrix[non_zero_variance_mask]

    #print(matrix.shape)  # arrがどのような次元を持っているか確認
    if matrix.shape[0] < 3:  # PCAには少なくとも3つのデータ点が必要
        raise ValueError("PCAを実行するには、少なくとも3つのデータ点が必要です。")

    # 各行の平均と分散を表示
    #print(f"Matrix mean: {np.mean(matrix, axis=1)}")
    #print(f"Matrix variance: {np.var(matrix, axis=1)}")

    #scaler = StandardScaler()
    #matrix_standardized = scaler.fit_transform(matrix)
    
    try:
        pca.fit(matrix)
        pca_result = pca.transform(matrix)

    except Exception as e:
        print(f"PCA fitting error: {e}")

    # PCAモデルを保存
    #with open('/save_pkl/pca_model.pkl', 'wb') as f:
    #    pickle.dump(pca, f)
    
    #print("saving pca data")
    
    # ここに既存のプロット処理や表示処理を追加
    fig = plt.figure(figsize=(10, 8))
    ay = fig.add_subplot(111, projection='3d')
    colors = ['red', 'green', 'blue', 'magenta', 'yellow', 'cyan', 'orange', 'purple', 'pink', 'brown', 'black', 'white', 'gray', 'lime', 'navy', 'teal', 'violet', 'indigo']
    markers = ['o', 's', '^', 'D', 'v']
    for i in range(len(pca_result)):
        color_index = i % len(colors)
        marker_index = i % len(markers)
        ay.scatter(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2],
                   color=colors[color_index], marker=markers[marker_index])
        
        if i // 4 < len(signal_names):
            #print(signal_names)
            #print(i)
            label = os.path.basename(signal_names[i // 4])
            ay.text(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2], label, size=10)
        else:
            label = os.path.basename(signal_names[i])
            ay.text(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2], label, size=10)

    for i in range(len(latest_pca_result)):
        color_index = i % len(colors)
        marker_index = i % len(markers)
        ay.scatter(latest_pca_result[i, 0], latest_pca_result[i, 1], latest_pca_result[i, 2],
                   color=colors[color_index], marker=markers[marker_index])

        if i // 4 < len(file_names):
            label = os.path.basename(file_names[i // 4])
            ay.text(latest_pca_result[i, 0], latest_pca_result[i, 1], latest_pca_result[i, 2], label, size=10)
    
    #ay.scatter(pca_result[:, 0], pca_result[:, 1], pca_result[:, 2], color='red', label='New Data')
    ay.set_title('PCA: FFT Components')
    ay.set_xlabel('First Principal Component')
    ay.set_ylabel('Second Principal Component')
    ay.set_zlabel('Third Principal Component')
    ay.grid(True)
    #if len(signal_names) > 0:  # ラベルがある場合のみ表示
        #ay.legend()
    user_ip = os.environ.get('REMOTE_ADDR')
    png_filename = f'/var/www/html/pca_3d_scatter_{user_ip}2.png'
    plt.savefig(png_filename, format='png')
    plt.show()
    # 開きたいHTMLファイルのパスを指定
    html_file_path = os.path.abspath('/var/www/html/test.html')
    
    # ブラウザでHTMLファイルを開く
    webbrowser.open(f'file://{html_file_path}')
    # 生成した画像を表示するHTMLコードを作成
    html_output = f'''
    <html>
    <head><title>PCA Mapping Result</title></head>
    <body>
    <h1>PCA Mapping Result</h1>
    <h2>Your select data is signal"n"</h2>
    <img src="/pca_3d_scatter_{user_ip}2.png" alt="Generated Image">
    </body>
    </html>
    '''
    
    # HTTPヘッダーとコンテンツを出力
    #print("Content-Type: text/html\n")
    print(html_output)
    
    #dleteFile()
    #print(read_data())

# 主成分分析と3Dプロットを行う関数
def perform_pca_and_plot(FFT_list, dates, signal_names):
    matrix = np.array(FFT_list)

    # データの分散がゼロの行を除去
    non_zero_variance_mask = np.var(matrix, axis=1) > 0
    matrix = matrix[non_zero_variance_mask]

    #scaler = StandardScaler()
    #matrix_standardized = scaler.fit_transform(matrix)
    pca_result = pca.fit_transform(matrix)
    
    #pca_result = pca.transform(matrix)
    
    # PCAモデルを保存
    #with open('/save_pkl/pca_model.pkl', 'wb') as f:
    #    pickle.dump(pca, f)
    
    #print("PCAモデルが保存されました。")
    
    # PCA結果をCSVファイルに保存
    #pca_df = pd.DataFrame(pca_result, columns=['PC1', 'PC2', 'PC3'])
    #pca_df['Date'] = dates
    #pca_df['Signal Name'] = signal_names
    #csv_file_path = "/save_predict/pca_results.csv"
    #pca_df.to_csv(csv_file_path, index=False)
    #print(f"PCA results saved to {csv_file_path}")

    # ここに既存のプロット処理や表示処理を追加
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')
    colors = ['red', 'green', 'blue', 'magenta', 'yellow', 'cyan', 'orange', 'purple', 'pink', 'brown', 'black', 'white', 'gray', 'lime', 'navy', 'teal', 'violet', 'indigo', 'gold', 'silver', 'coral', 'turquoise', 'maroon', 'olive', 'beige', 'chocolate', 'lavender', 'salmon', 'ivory', 'khaki', 'plum']
    markers = ['o', 's', '^', 'D', 'v']

    for i in range(len(pca_result)):
        color_index = i % len(colors)
        marker_index = i % len(markers)
        ax.scatter(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2],
                   color=colors[color_index], marker=markers[marker_index])

        if i // 4 < len(file_names):
            label = os.path.basename(file_names[i // 4])
            ax.text(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2], label, size=10)
        #else:
            #label = os.path.basename(file_names[i])
            #ax.text(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2], label, size=10)

    ax.set_title('PCA: FFT Components (3D)')
    ax.set_xlabel('First Principal Component')
    ax.set_ylabel('Second Principal Component')
    ax.set_zlabel('Third Principal Component')
    ax.grid(True)
    #if len(signal_names) > 0:  # ラベルがある場合のみ表示
        #ax.legend()
    user_ip = os.environ.get('REMOTE_ADDR')
    png_filename = f'/var/www/html/pca_3d_scatter_{user_ip}.png'
    plt.savefig(png_filename, format='png')
    plt.show()
    # 開きたいHTMLファイルのパスを指定
    html_file_path = os.path.abspath('/var/www/html/test.html')

    # ブラウザでHTMLファイルを開く
    webbrowser.open(f'file://{html_file_path}')
    # 生成した画像を表示するHTMLコードを作成
    html_output = f'''
    <html>
    <head><title>PCA Result</title></head>
    <body>
    <h1>PCA result using select datas</h1>
    <img src="/pca_3d_scatter_{user_ip}.png" alt="Generated Image">
    </body>
    </html>
    '''
    
    # HTTPヘッダーとコンテンツを出力
    #print("Content-Type: text/html\n")
    print(html_output)
    
    #dleteFile()
    #print(read_data())
    
    # 波形データを読み込む
    sound_file_path = '/home/g023c1133/swept_sine.wav'
    sample_rate, sound_data = wavfile.read(sound_file_path)
    env = generate_envelope(sound_data.astype(float), sample_rate, 10, 24000)
    json_data = load_json_files([f"/save2/{input_text}.json"])
    #print(f"json_data:{json_data}")
    FFT_list, dates, signal_names = process_signals(json_data, env, sample_rate)
    RE_perform_pca_and_plot(FFT_list, dates, signal_names, pca_result)
    

def read_data():
    # 新しい場所をリストにする
    new_place = [input_text]
    
    for collection_name in new_place:
        collection_ref = db.collection(collection_name)
        docs = collection_ref.stream()

        collection_data = {}

        for doc in docs:
            doc_data = doc.to_dict()
            if 'floatArray' in doc_data:
                collection_data[doc.id] = doc_data['floatArray']

        json_file_path = os.path.join(save_directory, f"{collection_name}.json")
        try:
            with open(json_file_path, 'w', encoding='utf-8') as json_file:
                json.dump(collection_data, json_file, ensure_ascii=False, indent=4)
            #print(f"Saved JSON to: {json_file_path}")
        except IOError as e:
            print(f"Error writing file: {e}")

    # 音声データの読み込み
    sound_file_path = '/home/g023c1133/swept_sine.wav'
    try:
        sample_rate, sound_data = wavfile.read(sound_file_path)
        env = generate_envelope(sound_data.astype(float), sample_rate, 10, 24000)
    except Exception as e:
        print(f"Error reading sound file: {e}")
        return  # エラーが発生した場合は処理を中断

    # JSONファイルの読み込み
    json_file_path = f"/save/{input_text}.json"
    #print(f"read-pass: {json_file_path}")

    
    try:
        #print(f"read-pass-try: {json_file_path}")

        result_dict = {}
        #print("+")
        with open(json_file_path, 'r') as file:
            data = json.load(file)
        result_dict[file_name] = data
        #print("2")

        FFT_list, dates, signal_names = process_signals(result_dict, env, sample_rate)
        #print("one,")

        # FFT_list, dates, signal_namesを/new_dataに保存
        fft_list_as_lists = [fft_array.tolist() for fft_array in FFT_list]

        # すべての配列をリストに変換
        new_data = {
            "FFT_list": fft_list_as_lists,
            "dates": dates,
            "signal_names": signal_names
        }
        
        #print("two,")

        new_data_file_path = ("/new_data/new_data.json")
        # JSON形式で保存
        with open(new_data_file_path, 'w') as f:
            json.dump(fft_list_as_lists, f, indent=4)
        #print(f"Saved new data to: {new_data_file_path}")

    except Exception as e:
        print(f"Error processing signals: {e}")

    
    """
    # 学習済みデータ（FFT_list）に基づきPCAと類似データの推論
    scaler = StandardScaler()
    FFT_matrix = np.array(FFT_list)
    scaler.fit(FFT_matrix)
    pca = PCA(n_components=3)
    pca_result_list = pca.fit_transform(scaler.transform(FFT_matrix))
    
    # 推論
    closest_index, closest_distance = predict_new_data_position(FFT_list, new_data_fft_abs, scaler, pca)
    
    # 推論結果の表示
    print("Content-Type: text/html\n")
    print(f"The closest data point is at index {closest_index} with a distance of {closest_distance}.")
    print(f"Corresponding date: {dates[closest_index]}, signal name: {signal_names[closest_index]}")

    return "The closest data point is at index {closest_index} with a distance of {closest_distance}."
    """

# 合体したPCAとプロット関数
def perform_pca_and_plot_with_mapping(FFT_list, dates, signal_names, new_data):
    # PCA適用のためにデータを行列に変換
    matrix = np.array(FFT_list)

    # データの分散がゼロの行を除去
    non_zero_variance_mask = np.var(matrix, axis=1) > 0
    matrix = matrix[non_zero_variance_mask]

    # データポイントが少なすぎる場合のエラーチェック
    if matrix.shape[0] < 3:
        raise ValueError("PCAを実行するには、少なくとも3つのデータ点が必要です。")

    # PCAモデルの生成と適用
    try:
        pca.fit(matrix)
        pca_result = pca.transform(matrix)
    except Exception as e:
        print(f"PCA fitting error: {e}")
        return

    # PCAモデルを保存
    with open('/save_pkl/pca_model.pkl', 'wb') as f:
        pickle.dump(pca, f)

    # PCA結果をCSVに保存
    pca_df = pd.DataFrame(pca_result, columns=['PC1', 'PC2', 'PC3'])
    pca_df['Date'] = dates
    pca_df['Signal Name'] = signal_names
    csv_file_path = "/save_predict/pca_results.csv"
    pca_df.to_csv(csv_file_path, index=False)

    # 新しいデータをPCA空間に写像
    try:
        new_pca_result = pca.transform(new_data)
    except Exception as e:
        print(f"PCA mapping error: {e}")
        return

    # プロット処理（元のデータと新しいデータを3Dに表示）
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')
    colors = ['red', 'green', 'blue', 'magenta', 'yellow', 'cyan', 'orange', 'purple', 'pink', 'brown', 'black', 'white', 'gray', 'lime', 'navy', 'teal', 'violet', 'indigo']
    markers = ['o', 's', '^', 'D', 'v']

    # 元データのプロット
    for i in range(len(pca_result)):
        color_index = i % len(colors)
        marker_index = i % len(markers)
        ax.scatter(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2],
                   color=colors[color_index], marker=markers[marker_index])
        #label = os.path.basename(signal_names[i // 4]) if i // 4 < len(signal_names) else signal_names[i]
        #ax.text(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2], label, size=10)

        if i // 4 < len(file_names):
            label = os.path.basename(file_names[i // 4])
            ax.text(pca_result[i, 0], pca_result[i, 1], pca_result[i, 2], label, size=10)
    ax.set_title('PCA: FFT Components with New Data (3D)')
    ax.set_xlabel('First Principal Component')
    ax.set_ylabel('Second Principal Component')
    ax.set_zlabel('Third Principal Component')
    ax.grid(True)

    user_ip = os.environ.get('REMOTE_ADDR')
    png_filename = f'/var/www/html/origin_pca_3d_scatter_{user_ip}.png'
    plt.savefig(png_filename, format='png')
    plt.show()

    # 新しいデータのプロット
    for i in range(len(new_pca_result)):
        color_index = i % len(colors)
        marker_index = i % len(markers)
        ax.scatter(new_pca_result[i, 0], new_pca_result[i, 1], new_pca_result[i, 2],
                   color=colors[color_index], marker=markers[marker_index])
        ax.text(new_pca_result[i, 0], new_pca_result[i, 1], new_pca_result[i, 2], f"signal {i+1}", size=10)

    ax.set_title('PCA: FFT Components with New Data (3D)')
    ax.set_xlabel('First Principal Component')
    ax.set_ylabel('Second Principal Component')
    ax.set_zlabel('Third Principal Component')
    ax.grid(True)

    user_ip = os.environ.get('REMOTE_ADDR')
    png_filename = f'/var/www/html/pca_3d_scatter_{user_ip}.png'
    plt.savefig(png_filename, format='png')
    plt.show()

    # 寄与率の取得
    explained_variance_ratio = pca.explained_variance_ratio_

    # HTML出力の準備
    html_file_path = os.path.abspath('/var/www/html/test.html')
    webbrowser.open(f'file://{html_file_path}')
    html_output = f'''
    <html>
    <head><title>PCA Result with New Data</title></head>
    <body>
    <h1>PCA Result with New Data</h1>
    <p>'signal "n"' is your select data.</p>
    <img src="/pca_3d_scatter_{user_ip}.png" alt="Generated Image">
    <h1>PCA Result of Origin Data</h1>
    <img src="/origin_pca_3d_scatter_{user_ip}.png" alt="Generated Image">
    </body>
    </html>
    '''

    print(html_output)
    print(f"PC1: {explained_variance_ratio[0]:.2%}")
    print(f"PC2: {explained_variance_ratio[1]:.2%}")
    print(f"PC3: {explained_variance_ratio[2]:.2%}")

# メイン処理
def main():
    json_data = load_json_files(file_names)

    # 波形データを読み込む
    sound_file_path = '/home/g023c1133/swept_sine.wav'
    sample_rate, sound_data = wavfile.read(sound_file_path)
    env = generate_envelope(sound_data.astype(float), sample_rate, 10, 24000)
    FFT_list, dates, signal_names = process_signals(json_data, env, sample_rate)
    #perform_pca_and_plot(FFT_list, dates, signal_names)

    json_data = load_json_files([f"/save2/{input_text}.json"])
    FFT_list2, dates2, signal_names2 = process_signals(json_data, env, sample_rate)
    #RE_perform_pca_and_plot(FFT_list, dates, signal_names, pca_result)

    perform_pca_and_plot_with_mapping(FFT_list, dates, signal_names, FFT_list2)
    dleteFile("/save")
    dleteFile("/save2")

def dleteFile(directory):
    # 保存先ディレクトリ
    save_directory = directory
    
    # 保存先ディレクトリが存在する場合、ファイルを削除
    if os.path.exists(save_directory):
        for filename in os.listdir(save_directory):
            file_path = os.path.join(save_directory, filename)
            try:
                if os.path.isfile(file_path):
                    os.remove(file_path)  # ファイルを削除
                    #print(f"Deleted: {file_path}")
                elif os.path.isdir(file_path):
                    os.rmdir(file_path)  # ディレクトリを削除（空である必要があります）
                    #print(f"Deleted directory: {file_path}")
            except Exception as e:
                print(f"Error deleting {file_path}: {e}")
    else:
        print(f"The directory {save_directory} does not exist.")


# 新しいデータのPCA変換と最も近いデータの推論を行う関数
def predict_new_data_position(FFT_list, new_data_fft, scaler, pca):
    # 新しいデータを標準化
    new_data_standardized = scaler.transform([new_data_fft])
    
    # 新しいデータをPCAに変換
    new_data_pca = pca.transform(new_data_standardized)

    # 各FFTデータのPCA結果とのユークリッド距離を計算
    distances = [euclidean(new_data_pca[0], pca_result) for pca_result in pca_result_list]
    
    # 最も近いデータのインデックスを取得
    closest_index = np.argmin(distances)
    
    return closest_index, distances[closest_index]


if __name__ == "__main__":
    main()

