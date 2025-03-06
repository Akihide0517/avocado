#!/usr/bin/env python3
import pickle
import os
import json
import numpy as np
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA

# 保存先ディレクトリ
save_directory = "/save"
new_data_directory = "/new_data"
pca_model_file = "/save_predict/pca_results.csv"  # PCAモデルの保存先をCSVに変更

# PCAモデルを読み込む
with open('/save_pkl/pca_model.pkl', 'rb') as f:
    pca = pickle.load(f)

# 新しいデータをロードする関数
def load_new_data(directory):
    new_data = []
    for file_name in os.listdir(directory):
        if file_name.endswith(".json"):
            with open(os.path.join(directory, file_name), 'r') as file:
                data = json.load(file)
                # JSONから読み込んだデータをNumPy配列に変換
                fft_data = [np.array(entry) for entry in data]
                new_data.append(fft_data)
    return np.array(new_data)

# 新しいデータを処理して主成分得点を計算する関数
def calculate_pca_scores(new_data):
    # データを2次元に変形（PCAに適用するために適切な形に変換）
    reshaped_data = new_data.reshape(new_data.shape[0] * new_data.shape[1], new_data.shape[2])
    #print(reshaped_data)
    #print(new_data)
    scores = pca.transform(reshaped_data)  # PCA得点の計算
    return scores

# PCA得点をプロットして画像を保存する関数
def plot_pca_scores(scores):
    plt.figure(figsize=(10, 8))
    plt.scatter(scores[:, 0], scores[:, 1], c='blue', marker='o', edgecolor='k', s=100)
    plt.title('PCA Scores')
    plt.xlabel('First Principal Component')
    plt.ylabel('Second Principal Component')
    plt.grid()
    
    # 画像を保存
    user_ip = os.environ.get('REMOTE_ADDR', 'localhost')
    png_filename = f'/var/www/html/pca_scores_{user_ip}.png'
    plt.savefig(png_filename, format='png')
    plt.close()
    
    return png_filename

# HTMLを生成する関数
def generate_html(image_path):
    html_output = f'''
    <html>
    <head><title>PCA Scores</title></head>
    <body>
    <h1>PCA Scores Result</h1>
    <img src="{image_path}" alt="PCA Scores">
    </body>
    </html>
    '''
    return html_output

def main():
    # 新しいデータの読み込み
    new_data = load_new_data(new_data_directory)

    # PCA得点の計算
    scores = calculate_pca_scores(new_data)

    # 得点をプロットして画像を保存
    image_path = plot_pca_scores(scores)

    # HTMLを生成
    html_output = generate_html(image_path)

    # HTTPヘッダーとコンテンツを出力
    print("Content-Type: text/html\n")
    print(html_output)

if __name__ == "__main__":
    main()
x
