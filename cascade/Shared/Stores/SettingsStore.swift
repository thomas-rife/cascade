//
//  SettingsStore.swift
//  cascade
//
//  Created by Thomas Rife on 5/31/26.
//

import Foundation
import Combine

enum PlaybackQualityPreset: Int, CaseIterable, Identifiable {
    case mbps3
    case mbps5
    case mbps8
    case mbps12
    case mbps20
    case mbps40
    case original

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .mbps40:
            return "40 Mbps"
        case .mbps20:
            return "20 Mbps"
        case .mbps12:
            return "12 Mbps"
        case .mbps8:
            return "8 Mbps"
        case .mbps5:
            return "5 Mbps"
        case .mbps3:
            return "3 Mbps"
        }
    }

    var maxStreamingBitrate: Int? {
        switch self {
        case .original:
            return nil
        case .mbps40:
            return 40_000_000
        case .mbps20:
            return 20_000_000
        case .mbps12:
            return 12_000_000
        case .mbps8:
            return 8_000_000
        case .mbps5:
            return 5_000_000
        case .mbps3:
            return 3_000_000
        }
    }
    
    var sliderValue: Double {
        Double(rawValue)
    }

    var allowsDirectPlay: Bool {
        self == .original
    }

    var preferredPlaybackBitrate: Int {
        maxStreamingBitrate ?? 120_000_000
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let playbackQualityRawValue = "playbackQualityRawValue"
    }

    @Published private(set) var playbackQuality: PlaybackQualityPreset {
        didSet {
            UserDefaults.standard.set(playbackQuality.rawValue, forKey: Keys.playbackQualityRawValue)
        }
    }

    init() {
        if UserDefaults.standard.object(forKey: Keys.playbackQualityRawValue) != nil {
            let rawValue = UserDefaults.standard.integer(forKey: Keys.playbackQualityRawValue)
            playbackQuality = PlaybackQualityPreset(rawValue: rawValue) ?? .original
        } else {
            playbackQuality = .original
        }
    }

    var sliderRange: ClosedRange<Double> {
        0...Double(PlaybackQualityPreset.allCases.count - 1)
    }

    var sliderValue: Double {
        get { playbackQuality.sliderValue }
        set {
            let roundedValue = Int(newValue.rounded())
            playbackQuality = PlaybackQualityPreset(rawValue: roundedValue) ?? .original
        }
    }
}
