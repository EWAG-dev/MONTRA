import SwiftUI
import UIKit

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.montraTextSecondary)
            .kerning(1.2)
    }
}

struct NotificationBellButton: View {
    var action: (() -> Void)? = nil
    var showsBadge: Bool = true
    var size: CGFloat = 34

    private var cornerRadius: CGFloat {
        max(9, size * 0.26)
    }

    var body: some View {
        Button {
            action?()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: size * 0.47, weight: .medium))
                    .foregroundColor(.montraTextPrimary)
                    .frame(width: size, height: size)
                    .background(Color.montraSurface)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.montraCardBorder, lineWidth: 0.9)
                    )

                if showsBadge {
                    Circle()
                        .fill(Color.montraOrange)
                        .frame(width: 8, height: 8)
                        .offset(x: 1, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ClientMessagesStyleHeader: View {
    let title: String
    var onNotificationTap: (() -> Void)? = nil
    var onProfileTap: (() -> Void)? = nil
    @AppStorage("dashboardProfileImageData") private var profileImageData: Data = Data()

    var body: some View {
        HStack(spacing: 8) {
            NotificationBellButton(action: onNotificationTap)

            Spacer()

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .kerning(0.2)

            Spacer()

            Button {
                onProfileTap?()
            } label: {
                ZStack {
                    if let uiImage = UIImage(data: profileImageData), !profileImageData.isEmpty {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.montraSurface)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.montraOrange)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            .overlay(Circle().stroke(Color.montraOrange.opacity(0.8), lineWidth: 1))
        }
        .padding(.top, 0)
    }
}

struct TrainerCompactTopBar: View {
    let title: String
    let onMenuTap: () -> Void
    var trailingIcon: String? = nil
    var onTrailingTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onMenuTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .kerning(0.2)

            Spacer()

            if let trailingIcon, let onTrailingTap {
                Button(action: onTrailingTap) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.montraOrange)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.top, 2)
    }
}

struct TrainerStatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.montraTextPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.montraTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .montraCard(radius: 14)
    }
}