import JellyfinAPI
import SwiftUI

struct MovieTrackSelector: View {
    @ObservedObject var options: MoviePlaybackOptions
    let retry: () -> Void

    var body: some View {
        Menu {
            if options.isLoading {
                Text("Loading tracks…")
            } else if options.errorMessage != nil {
                Button("Try Again", action: retry)
            } else {
                Menu {
                    Picker("Audio", selection: $options.selection.audioStreamIndex) {
                        Text("Automatic").tag(nil as Int?)
                        trackRows(type: .audio)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Audio", systemImage: "speaker.wave.2")
                }

                Menu {
                    Picker("Subtitles", selection: $options.selection.subtitleStreamIndex) {
                        Text("Automatic").tag(nil as Int?)
                        Text("Off").tag(-1 as Int?)
                        trackRows(type: .subtitle)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Subtitles", systemImage: "captions.bubble")
                }
            }
        } label: {
            #if os(iOS)
            Image(systemName: "text.bubble")
                .frame(width: 44, height: 44)
            #else
            Label("Audio & Subtitles", systemImage: "text.bubble")
            #endif
        }
        .accessibilityLabel("Audio & Subtitles")
    }

    @ViewBuilder
    private func trackRows(type: MediaStreamType) -> some View {
        let tracks = options.streams.filter { $0.type == type && $0.index != nil }
        ForEach(tracks, id: \.index) { track in
            Text(title(for: track)).tag(track.index)
        }
        if tracks.isEmpty {
            Text(type == .audio ? "No audio tracks available" : "No subtitle tracks available")
                .disabled(true)
        }
    }

    private func title(for stream: MediaStream) -> String {
        var title = stream.displayTitle ?? ""
        if title.isEmpty {
            var parts = [stream.language, stream.title, stream.codec?.uppercased()]
                .compactMap { $0 }.filter { !$0.isEmpty }
            if let channels = stream.channels { parts.append("\(channels)ch") }
            title = parts.isEmpty ? "Track \(stream.index ?? 0)" : parts.joined(separator: " • ")
        }
        if stream.isForced == true, !title.localizedCaseInsensitiveContains("forced") {
            title += " • Forced"
        }
        return title
    }
}
