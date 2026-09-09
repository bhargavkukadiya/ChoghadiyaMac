# Contributing to Choghadiya for Mac

Thank you for your interest in contributing to **Choghadiya for Mac**! We welcome bug reports, feature enhancements, documentation improvements, and localization contributions.

This document outlines the guidelines and workflows for developing and contributing to the project.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Fork & Clone](#fork--clone)
- [Project Configuration with XcodeGen](#project-configuration-with-xcodegen)
- [Coding Standards & Style Guide](#coding-standards--style-guide)
  - [Indentation & Formatting](#indentation--formatting)
  - [Code Organization & MARK Annotations](#code-organization--mark-annotations)
  - [Concurrency & Memory Safety](#concurrency--memory-safety)
  - [Localization Guidelines](#localization-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Commit Message Conventions](#commit-message-conventions)
- [Submitting a Pull Request](#submitting-a-pull-request)

---

## Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free environment for all contributors. Please treat fellow community members with respect, patience, and empathy.

---

## Getting Started

### Prerequisites
- **macOS:** macOS 12.0 Monterey or later (macOS 14+ Sonoma/Sequoia recommended for widget intent development).
- **Xcode:** Xcode 16.0 or later.
- **XcodeGen:** Version 2.46+ (`brew install xcodegen`).
- **SwiftFormat:** Version 0.50+ (`brew install swiftformat`).

### Fork & Clone
1. Fork the repository on GitHub.
2. Clone your fork locally and add the upstream remote:
   ```bash
   git clone https://github.com/<your-username>/ChoghadiyaMac.git
   cd ChoghadiyaMac
   git remote add upstream https://github.com/bhargavkukadiya/ChoghadiyaMac.git
   ```
3. Create a descriptive feature branch:
   ```bash
   git checkout -b feat/add-widget-family
   ```

---

## Project Configuration with XcodeGen

`project.yml` is the **single source of truth** for project structure, build settings, target dependencies, entitlements, and schemes.

- **Do not manually edit `ChoghadiyaMac.xcodeproj`**.
- Whenever you add, delete, or move files, or update build settings, modify `project.yml` and regenerate the project:
  ```bash
  xcodegen generate
  ```
- Always commit the updated `ChoghadiyaMac.xcodeproj/project.pbxproj` and `ChoghadiyaMac.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` alongside your changes.

---

## Coding Standards & Style Guide

We maintain strict code hygiene to keep the codebase clean, readable, and maintainable.

### Indentation & Formatting
- **Standard:** 4-space indentation across all Swift code.
- Run `swiftformat` before committing:
  ```bash
  swiftformat . --indent 4 --exclude build,.build
  ```

### Code Organization & MARK Annotations
Organize every Swift file with logical, structured `// MARK: -` sections:
```swift
// MARK: - View Model Properties
@Published var state: ScheduleViewState = .idle

// MARK: - Initialization & Lifecycle
init(locationManager: LocationManaging) { ... }

// MARK: - Public Actions
func refreshSchedule() { ... }

// MARK: - Private Helpers
private func handleCalculationResult() { ... }
```

### Concurrency & Memory Safety
- **MainActor Isolation:** Presentation state machines (`ContentViewModel`) and view lifecycle handlers must remain isolated to `@MainActor`.
- **Task Lifecycle:** Always store handles to background `Task` instances (`scheduleTask`, `permissionTask`) and cancel in-flight tasks before launching new ones or on deinitialization.
- **Memory Management:** Use `[weak self]` in non-isolated closures and long-lived asynchronous tasks to avoid retain cycles.

### Localization Guidelines
- All user-facing strings must be localized using `String(localized: "...")` or standard SwiftUI `Text("...")` localizable keys.
- Update `Shared/Localizable.xcstrings` when adding new strings.

---

## Testing Guidelines

Every bug fix or feature must include automated test coverage:

- **Deterministic Fixtures:** Use `ScheduleFixtures`, `TestClock`, and `MockLocationManager` instead of live network calls or actual CoreLocation hardware.
- **Run the Test Suite:**
  ```bash
  xcodebuild test \
             -scheme ChoghadiyaMacApp \
             -destination 'platform=macOS' \
             CODE_SIGN_IDENTITY="" \
             CODE_SIGNING_REQUIRED=NO \
             CODE_SIGN_ENTITLEMENTS="" \
             CODE_SIGNING_ALLOWED=NO
  ```
- **Passing Standard:** All 38+ unit and integration tests must pass with 0 failures before opening a pull request.

---

## Commit Message Conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` A new feature (e.g., `feat: add lock screen widget complication`)
- `fix:` A bug fix (e.g., `fix: prevent race condition in rapid date selection`)
- `docs:` Documentation improvements (e.g., `docs: update widget intent setup in README`)
- `style:` Formatting, whitespace, or code hygiene changes (e.g., `style: format all files with swiftformat 4-space indent`)
- `refactor:` Code refactoring without changing user-facing behavior (e.g., `refactor: extract forward geocoding protocol`)
- `test:` Adding or updating tests (e.g., `test: add regression test for pre-sunrise rollover`)
- `chore:` Build scripts, XcodeGen, or CI updates (e.g., `chore: update github actions runner to macos-15`)

---

## Submitting a Pull Request

1. Push your branch to your GitHub fork:
   ```bash
   git push origin feat/your-feature-name
   ```
2. Open a Pull Request against the `main` branch.
3. Fill out the pull request template completely:
   - Provide a clear description and motivation for the change.
   - Attach screenshots or screen recordings for visible UI/UX changes.
   - Confirm that all unit tests pass and formatting has been applied.
4. Respond promptly to code review feedback.
