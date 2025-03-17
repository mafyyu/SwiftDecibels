import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()

    var body: some View {
        VStack {
            Text("デシベル: \(String(format: "%.1f", audioRecorder.decibels)) dB")
                .font(.largeTitle)
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
    @Published var isRecording: Bool = false //計測するときはtrue
    
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
        
        let referenceLevel: Float = 1.0
        
        DispatchQueue.main.async {
            self.decibels = 20 * log10(adjustedRMS / referenceLevel) + 94.0
        }
        print(self.decibels) //デバック用
        
    }
}
