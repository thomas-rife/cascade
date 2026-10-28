//
//  TVVideoPlayerView.swift
//  cascade-tvOS
//
//  Created by Thomas Rife on 6/1/26.
//

import AVKit
import SwiftUI

struct TVVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}
