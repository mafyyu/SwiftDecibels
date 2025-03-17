import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()

    var body: some View {
        VStack {
            Text("デシベル: \(String(format: "%.1f", audioRecorder.decibels)) dB")
                .font(.largeTitle)
                .padding()
            
            Text("平均ピーク振幅: \(String(format: "%.2f", audioRecorder.peakAmplitude))")
                .font(.title)
                .padding()

            Button(action: {
                if audioRecorder.isRecording {
                    audioRecorder.stopRecording()
                } else {
                    audioRecorder.startRecording()
                }
            }) {
                Text(audioRecorder.isRecording ? "停止" : "計測開始")
                    .font(.title)
                    .padding()
                    .frame(width: 200, height: 50)
                    .background(audioRecorder.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

class AudioRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine!
    private var audioInputNode: AVAudioInputNode!
    
    @Published var decibels: Float = 0.0
    @Published var peakAmplitude: Float = 0.0
    @Published var isRecording: Bool = false
    
    init() {
        setupRecorder()
    }
    
    private func setupRecorder() {
        audioEngine = AVAudioEngine()
        audioInputNode = audioEngine.inputNode
        
        let format = audioInputNode.inputFormat(forBus: 0)
        audioInputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { (buffer, time) in
            self.calculateDecibels(buffer: buffer)
        }
    }
    
    func startRecording() {
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine start error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        isRecording = false
    }
    
    private func calculateDecibels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        var sumOfSquares: Float = 0.0
        var peak: Float = 0.0
        
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sumOfSquares += sample * sample
            if sample > peak {
                peak = sample
            }
        }
        
        // RMS (Root Mean Square) を計算
        let rms = sqrt(sumOfSquares / Float(frameLength))
        
        // 0 に近い値を防ぐために最小値を設定
        let minRMS: Float = 1e-7  // これより小さいと -∞ dB になる
        let adjustedRMS = max(rms, minRMS)
        
        // 基準レベル (20μPa = 0.00002 Pa) に調整
        let referenceLevel: Float = 1.0  // 20μPa (人間の聴覚基準)
        
        // 環境騒音レベルに近づけるdB計算
        self.decibels = 20 * log10(adjustedRMS / referenceLevel) + 94.0 // デジタルdBからdBSPL変換
        
        // ピーク振幅も dB に変換
        let minPeak: Float = 1e-7
        let adjustedPeak = max(peak, minPeak)
        self.peakAmplitude = 20 * log10(adjustedPeak / referenceLevel)
        print(self.decibels)
    }
}
