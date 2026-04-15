import SwiftUI

struct FrequencyDetailView: View {
    @Bindable var viewModel: FrequencyDetailViewModel
    var onLeave: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showMembers = false
    @State private var showLeaveConfirm = false
    @State private var showDeleteConfirm = false
    @State private var codeCopied = false

    private var isCreator: Bool { viewModel.isCreator }

    var body: some View {
        ZStack {
            // Full yellow background like the reference image
            WTTheme.yellow.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Frequency display / waveform
                ZStack {
                    RadioFrequencyDisplay(
                        frequencyNumber: viewModel.frequency.displayFrequency,
                        channelName: viewModel.frequency.name
                    )
                    .opacity(viewModel.audioEngine.isRecording ? 0 : 1)

                    if viewModel.audioEngine.isRecording {
                        AudioWaveOverlay(
                            audioLevel: viewModel.audioEngine.audioLevel,
                            isActive: true
                        )
                        .frame(height: 100)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.audioEngine.isRecording)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Control buttons row
                controlsRow
                    .padding(.bottom, 8)

                // Live speaking indicator
                if let speaker = viewModel.speakingMember {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                        Text("\(speaker.displayName) parle...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.4))
                    .clipShape(.capsule)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                // Speaker grille + messages area
                ZStack {
                    // Speaker grille background
                    SpeakerGrilleView(
                        rows: 14,
                        columns: 10,
                        dotColor: WTTheme.yellowDark.opacity(0.5)
                    )

                    // Messages overlay
                    if !viewModel.messages.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.messages) { message in
                                    VoiceMessageRow(
                                        message: message,
                                        isPlaying: viewModel.playingMessageID == message.id,
                                        onTap: { viewModel.playMessage(message) }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(.black.opacity(0.3))
                        .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
                        .padding(.horizontal, 12)
                    }
                }
                .frame(maxHeight: .infinity)

                // Push to talk area
                pttArea
                    .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
        .sheet(isPresented: $showMembers) {
            MembersSheet(
                members: viewModel.members,
                frequencyName: viewModel.frequency.name,
                currentUserID: viewModel.userID,
                isCurrentUserCreator: viewModel.isCreator,
                onKick: { member in
                    Task { await viewModel.kickMember(member) }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Quitter la fréquence ?", isPresented: $showLeaveConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Quitter", role: .destructive) {
                onLeave?()
            }
        } message: {
            Text("Tu ne recevras plus les messages de \"\(viewModel.frequency.name)\"")
        }
        .alert("Supprimer la fréquence ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("La fréquence \"\(viewModel.frequency.name)\" sera supprimée pour tous les membres")
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WTTheme.black)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.3))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("WALKIE TALKIE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(WTTheme.black.opacity(0.6))
                    .tracking(2)
            }

            Spacer()

            HStack(spacing: 8) {
                // Leave or Delete button
                Button {
                    if isCreator {
                        showDeleteConfirm = true
                    } else {
                        showLeaveConfirm = true
                    }
                } label: {
                    Image(systemName: isCreator ? "trash.fill" : "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WTTheme.red)
                        .frame(width: 40, height: 40)
                        .background(WTTheme.red.opacity(0.15))
                        .clipShape(Circle())
                }

                // Share deep link
                ShareLink(item: viewModel.frequency.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WTTheme.black)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.3))
                        .clipShape(Circle())
                }
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 20) {
            Button { showMembers = true } label: {
                controlButton(icon: "person.2.fill", label: "\(viewModel.members.count)")
            }
            Button {
                UIPasteboard.general.string = viewModel.frequency.code
                codeCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    codeCopied = false
                }
            } label: {
                controlButton(
                    icon: codeCopied ? "checkmark" : "doc.on.clipboard",
                    label: codeCopied ? "Copié !" : viewModel.frequency.code
                )
            }
        }
    }

    private func controlButton(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(WTTheme.monoSmallFont)
        }
        .foregroundStyle(WTTheme.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.3))
        .clipShape(.capsule)
    }

    private var pttArea: some View {
        VStack(spacing: 14) {
            // Quick reactions
            QuickReactionBar(
                onReaction: { reaction in
                    viewModel.sendReaction(reaction)
                },
                isEnabled: !viewModel.audioEngine.isRecording && !viewModel.isSending
            )
            .padding(.horizontal, 20)

            // Status text
            Group {
                if viewModel.audioEngine.isRecording {
                    Text("ENREGISTREMENT...")
                        .foregroundStyle(WTTheme.black)
                } else if viewModel.isSending {
                    Text("ENVOI...")
                        .foregroundStyle(WTTheme.black.opacity(0.6))
                } else {
                    Text("MAINTENIR POUR PARLER")
                        .foregroundStyle(WTTheme.black.opacity(0.6))
                }
            }
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(2)

            PushToTalkButton(
                isRecording: viewModel.audioEngine.isRecording,
                progress: {
                    if case .recording(let p) = viewModel.audioEngine.recordingState {
                        return p
                    }
                    return 0
                }(),
                onStart: {
                    Task { _ = await viewModel.startRecording() }
                },
                onStop: {
                    Task { await viewModel.stopRecordingAndSend() }
                }
            )
        }
    }
}
