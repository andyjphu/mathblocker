//
//  OnboardingView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var authManager = AuthorizationManager.shared
    @State private var selectionManager = SelectionManager.shared
    @State private var showingAppPicker = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                authorizePage.tag(2)
                pickAppsPage.tag(3)
                readyPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .padding(.bottom, 8)

            Text("MathBlocker")
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Text("Earn your screen time\nby sharpening your mind.")
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

            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                stepRow(icon: "apps.iphone", color: .purple, title: "Choose apps to limit", subtitle: "Pick which apps get blocked after your daily budget")

                stepRow(icon: "clock.badge.exclamationmark", color: .orange, title: "Hit your time limit", subtitle: "A shield blocks those apps when time runs out")

                stepRow(icon: "function", color: .blue, title: "Solve to unlock", subtitle: "Answer math questions to earn more time")

                stepRow(icon: "star.fill", color: .yellow, title: "Get smarter", subtitle: "Track your streak and watch your skills grow")
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
                .foregroundStyle(.blue)

            Text("Screen Time Access")
                .font(.title)
                .fontWeight(.bold)

            Text("MathBlocker needs Screen Time permission to monitor app usage and block distracting apps.")
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
                        .background(.blue)
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

            Text("Choose Apps to Block")
                .font(.title)
                .fontWeight(.bold)

            Text("Select which apps should be blocked after your daily time budget runs out.")
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
                        .background(.purple)
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

    // MARK: - Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're Ready")
                .font(.title)
                .fontWeight(.bold)

            Text("Start solving math problems to earn screen time. You can adjust everything in Settings anytime.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "lock.shield", text: "Set a Screen Time Passcode for best protection")
                featureRow(icon: "hand.raised.fill", text: "You control everything — change anytime")
            }
            .padding(.top, 8)

            Spacer()

            Button {
                // Start monitoring if authorized and apps selected
                if authManager.isAuthorized && selectionManager.hasSelection {
                    MonitoringManager.shared.startMonitoring(budgetMinutes: 30)
                }
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
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
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func stepRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
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
