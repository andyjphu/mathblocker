//
//  OnboardingView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import FamilyControls
import UserNotifications

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var authManager = AuthorizationManager.shared
    @State private var selectionManager = SelectionManager.shared
    @State private var showingAppPicker = false

    var body: some View {
        ZStack {
            FrostedBackground()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                authorizePage.tag(2)
                pickAppsPage.tag(3)
                notificationsPage.tag(4)
                readyPage.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .fontDesign(.serif)
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("logo4xbg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.bottom, 8)

            Text("MathBlocker")
                .font(Theme.titleFont(size: 38))

            Text("trade math for screen time.\nsounds fair, right?")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            nextButton(page: 0)
        }
        .padding(32)
    }

    // MARK: - How It Works

    private var howItWorksPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("how it works")
                .font(Theme.titleFont(size: 28))

            VStack(alignment: .leading, spacing: 24) {
                stepRow(icon: "apps.iphone", color: .purple, title: "pick your apps", subtitle: "choose which apps to limit")

                stepRow(icon: "clock.badge.exclamationmark", color: .orange, title: "use up your time", subtitle: "apps get blocked when you go over")

                stepRow(icon: "function", color: .accent, title: "do some math", subtitle: "answer questions to earn more time")

                stepRow(icon: "star.fill", color: .yellow, title: "level up", subtitle: "track your progress over time")
            }
            .padding(.horizontal, 8)

            Spacer()

            nextButton(page: 1)
        }
        .padding(32)
    }

    // MARK: - Authorize

    private var authorizePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("screen time access")
                .font(Theme.titleFont(size: 28))

            Text("we need Screen Time permission to track usage and block apps when you're over your limit")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if authManager.isAuthorized {
                Label("Authorized", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            if authManager.isAuthorized {
                nextButton(page: 2)
            } else {
                Button {
                    Task { await authManager.requestAuthorization() }
                } label: {
                    Text("Authorize")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    withAnimation { currentPage = 3 }
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
    }

    // MARK: - Pick Apps

    private var pickAppsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "apps.iphone")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            Text("pick your apps")
                .font(Theme.titleFont(size: 28))

            Text("these are the apps that get blocked once you hit your daily limit")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if selectionManager.hasSelection {
                Label("Apps selected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            Spacer()

            if authManager.isAuthorized {
                Button {
                    showingAppPicker = true
                } label: {
                    Text(selectionManager.hasSelection ? "Change Selection" : "Select Apps")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.accent.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .familyActivityPicker(
                    isPresented: $showingAppPicker,
                    selection: $selectionManager.selection
                )
            }

            if selectionManager.hasSelection || !authManager.isAuthorized {
                nextButton(page: 3)
            }

            if !selectionManager.hasSelection && authManager.isAuthorized {
                Button {
                    withAnimation { currentPage = 4 }
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
    }

    // MARK: - Notifications

    @State private var notificationsGranted = false

    private var notificationsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("stay in the loop")
                .font(Theme.titleFont(size: 28))

            Text("we'll send you a heads up when you're about to hit your limit, so you can solve a few problems before your apps get blocked.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if notificationsGranted {
                Label("notifications enabled", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            Spacer()

            if notificationsGranted {
                nextButton(page: 4)
            } else {
                Button {
                    Task {
                        let granted = (try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound])) ?? false
                        notificationsGranted = granted
                    }
                } label: {
                    Text("notify me")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    withAnimation { currentPage = 5 }
                } label: {
                    Text("skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
    }

    // MARK: - Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("you're good to go")
                .font(Theme.titleFont(size: 28))

            Text("everything's set up. you can tweak it all in settings whenever.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "hand.raised.fill", text: "you're in control, change anything anytime")
            }
            .padding(.top, 8)

            Spacer()

            Button {
                if authManager.isAuthorized && selectionManager.hasSelection {
                    MonitoringManager.shared.startMonitoring(budgetMinutes: 30)
                }
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("let's go")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(32)
    }

    // MARK: - Components

    private func nextButton(page: Int) -> some View {
        Button {
            withAnimation { currentPage = page + 1 }
        } label: {
            Text("Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func stepRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .cardShadow()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.accent)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
