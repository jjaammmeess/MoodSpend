import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var localization: LocalizationManager
  @EnvironmentObject private var appSettings: AppSettings

  @State private var draftDisplayName = ""
  @State private var draftAvatarImageData: Data?
  @State private var draftAvatarPresetID: String?
  @State private var selectedAvatarItem: PhotosPickerItem?
  @State private var validationMessage: String?

  private var usesCustomPhoto: Bool { draftAvatarImageData != nil }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          heroAvatarSection

          VStack(alignment: .leading, spacing: 14) {
            sectionTitle(localization.text(.mineAvatarPreset))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
              avatarPresetButton(
                title: localization.text(.mineAvatarPresetDefault),
                isSelected: !usesCustomPhoto && draftAvatarPresetID == nil
              ) {
                selectableAvatar(
                  ProfileAvatarView(imageData: nil, presetID: nil, size: 54, isEmphasized: !usesCustomPhoto && draftAvatarPresetID == nil),
                  diameter: 54,
                  isSelected: !usesCustomPhoto && draftAvatarPresetID == nil
                )
              } action: {
                draftAvatarImageData = nil
                draftAvatarPresetID = nil
              }

              ForEach(AvatarPreset.allCases) { preset in
                let isSelected = !usesCustomPhoto && draftAvatarPresetID == preset.rawValue
                avatarPresetButton(
                  title: presetLabel(for: preset),
                  isSelected: isSelected
                ) {
                  selectableAvatar(
                    ProfileAvatarView(imageData: nil, presetID: preset.rawValue, size: 54, isEmphasized: isSelected),
                    diameter: 54,
                    isSelected: isSelected
                  )
                } action: {
                  draftAvatarImageData = nil
                  draftAvatarPresetID = preset.rawValue
                }
              }
            }
          }

          VStack(alignment: .leading, spacing: 14) {
            sectionTitle(localization.text(.mineAvatarCustomPhoto))
            AlbumPhotoPickerRow(
              title: localization.text(.mineAvatarAlbumSelectTitle),
              hint: localization.text(.mineAvatarAlbumSelectHint),
              selection: $selectedAvatarItem
            )
          }

          VStack(alignment: .leading, spacing: 10) {
            sectionTitle(localization.text(.mineProfileNickname))
            TextField(localization.text(.mineDisplayNamePlaceholder), text: $draftDisplayName)
              .font(.title3.weight(.semibold))
              .kerning(0.6)
              .monospacedDigit()
              .foregroundStyle(AppTheme.textPrimary)
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(Color.primary.opacity(0.035))
              )
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()

            Text(localization.text(.mineDisplayNameHint))
              .font(.caption)
              .foregroundStyle(AppTheme.textSecondary)

            if let validationMessage {
              Text(validationMessage)
                .font(.caption)
                .foregroundStyle(AppTheme.accentRisk)
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 34)
      }
      .background(AppTheme.pageBackground.ignoresSafeArea())
      .navigationTitle(localization.text(.mineAvatarSelectTitle))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(localization.text(.commonCancel)) {
            dismiss()
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            applyChangesAndDismiss()
          } label: {
            Text(localization.text(.mineAvatarDone))
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(AppTheme.cardBackground)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(Capsule().fill(AppTheme.actionBlue))
          }
        }
      }
    }
    .onAppear(perform: bootstrapDraft)
    .onChange(of: selectedAvatarItem) { _, newItem in
      guard let newItem else { return }
      Task {
        await updateAvatarFromAlbum(item: newItem)
      }
    }
  }

  private var heroAvatarSection: some View {
    VStack(spacing: 10) {
      Button {
        // Tap feedback only; album flow uses the row below.
      } label: {
        selectableAvatar(
          ProfileAvatarView(
            imageData: draftAvatarImageData,
            presetID: draftAvatarPresetID,
            size: 98,
            isEmphasized: true,
            showsStroke: false
          ),
          diameter: 98,
          isSelected: usesCustomPhoto,
          showsHeroBorder: true
        )
      }
      .buttonStyle(AvatarPressButtonStyle())
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 6)
  }

  @ViewBuilder
  private func selectableAvatar<Content: View>(
    _ avatar: Content,
    diameter: CGFloat,
    isSelected: Bool,
    showsHeroBorder: Bool = false
  ) -> some View {
    ZStack {
      avatar

      if showsHeroBorder {
        Circle()
          .stroke(Color.primary.opacity(0.06), lineWidth: 1)
          .frame(width: diameter, height: diameter)
      }

      if isSelected {
        AvatarBreathingSelectionRing(diameter: diameter)
      }
    }
    .frame(width: diameter, height: diameter)
  }

  private func bootstrapDraft() {
    if draftDisplayName.isEmpty {
      draftDisplayName = appSettings.displayName
      draftAvatarImageData = appSettings.avatarImageData
      draftAvatarPresetID = appSettings.avatarPresetID
    }
  }

  private func applyChangesAndDismiss() {
    let trimmed = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2, trimmed.count <= 20 else {
      validationMessage = localization.text(.mineDisplayNameInvalid)
      return
    }
    let normalized = String(trimmed.prefix(20))
    appSettings.displayName = normalized
    appSettings.avatarImageData = draftAvatarImageData
    appSettings.avatarPresetID = draftAvatarPresetID
    draftDisplayName = normalized
    validationMessage = nil
    dismiss()
  }

  private func avatarPresetButton<Preview: View>(
    title: String,
    isSelected: Bool,
    @ViewBuilder preview: () -> Preview,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 8) {
        preview()
        Text(title)
          .font(.caption)
          .foregroundStyle(isSelected ? AppTheme.textPrimary.opacity(0.88) : AppTheme.textSecondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(AvatarPressButtonStyle())
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 20, weight: .bold))
      .foregroundStyle(AppTheme.textPrimary)
  }

  private func presetLabel(for preset: AvatarPreset) -> String {
    switch localization.effectiveLanguage {
    case .zhHans, .zhHant:
      switch preset {
      case .ocean: return "海蓝"
      case .sunset: return "日落"
      case .lavender: return "薰衣草"
      case .forest: return "森林"
      case .rose: return "玫瑰"
      case .sky: return "晴空"
      }
    case .en, .system:
      switch preset {
      case .ocean: return "Ocean"
      case .sunset: return "Sunset"
      case .lavender: return "Lavender"
      case .forest: return "Forest"
      case .rose: return "Rose"
      case .sky: return "Sky"
      }
    }
  }

  private func updateAvatarFromAlbum(item: PhotosPickerItem) async {
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
            let sourceImage = UIImage(data: data),
            let preparedData = preparedAvatarData(from: sourceImage) else {
        return
      }
      await MainActor.run {
        draftAvatarImageData = preparedData
        draftAvatarPresetID = nil
      }
    } catch {
      return
    }
  }

  private func preparedAvatarData(from image: UIImage) -> Data? {
    let canvasSize = CGSize(width: 512, height: 512)
    let renderer = UIGraphicsImageRenderer(size: canvasSize)
    let normalized = renderer.image { _ in
      let aspect = max(canvasSize.width / image.size.width, canvasSize.height / image.size.height)
      let drawSize = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
      let origin = CGPoint(
        x: (canvasSize.width - drawSize.width) / 2,
        y: (canvasSize.height - drawSize.height) / 2
      )
      image.draw(in: CGRect(origin: origin, size: drawSize))
    }

    for quality in stride(from: 0.88, through: 0.5, by: -0.12) {
      if let data = normalized.jpegData(compressionQuality: quality), data.count <= 300_000 {
        return data
      }
    }
    return normalized.jpegData(compressionQuality: 0.45)
  }
}

private struct AlbumPhotoPickerRow: View {
  let title: String
  let hint: String
  @Binding var selection: PhotosPickerItem?

  var body: some View {
    PhotosPicker(selection: $selection, matching: .images) {
      HStack(spacing: 14) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.primary.opacity(0.06))
          .frame(width: 52, height: 52)
          .overlay(
            Image(systemName: "photo.on.rectangle.angled")
              .font(.system(size: 22, weight: .medium))
              .foregroundStyle(AppTheme.actionBlue.opacity(0.88))
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
          Text(hint)
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary.opacity(0.4))
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Selection ring & press feedback

private struct AvatarBreathingSelectionRing: View {
  let diameter: CGFloat

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
      let phase = timeline.date.timeIntervalSinceReferenceDate
      let pulse = 0.34 + 0.48 * (sin(phase * 2 * .pi / 1.75) + 1) / 2
      Circle()
        .stroke(Color(hex: "3F6F76").opacity(pulse), lineWidth: 2)
        .frame(width: diameter + 5, height: diameter + 5)
    }
    .allowsHitTesting(false)
  }
}

private struct AvatarPressButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}
