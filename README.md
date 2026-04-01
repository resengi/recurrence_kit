# Flutter Package Template

This is a boilerplate template for creating new Flutter/Dart packages. It uses `{{ package.name }}` as a placeholder throughout the codebase — including file names, imports, and configuration — so that when you generate a new package, every reference needs to be replaced with your actual package name.

---

## Template Variable

Every occurrence of `{{ package.name }}` in this template (in file contents **and** file names) will need to be replaced with the package name you provide at generation time. You will encounter it in:

- File and directory names (e.g., `lib/{{ package.name }}.dart`)
- `pubspec.yaml` fields
- Dart `library` declarations
- Import statements
- Test file references

---

## Package Structure

Below is the full directory layout and the role of each file and folder.

```
{{ package.name }}/
├── .github/
│   └── workflows/
│       └── ci.yml
│       └── publish.yml
│       └── release.yml
│   └── CODEOWNERS
│   └── melos.yaml
├── assets/
├── lib/
│   ├── {{ package.name }}.dart       # Public barrel file
│   └── src/                           # Private implementation code
├── test/
├── example/
│   └── lib/
│       └── main.dart
│   └── analysis_options.yaml
│   └── pubspec.yaml
│   └── README.md
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

## Where to Add Code

### `lib/{{ package.name }}.dart` — Public API Barrel File

This is the entry point that consumers of your package will import. It should **only** contain `export` statements that expose your public API. Do not put implementation logic here.

```dart
/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

export 'src/<file_name>.dart';
// Export additional public files here as you add them.
```

When a consumer installs your package, they will import it as:

```dart
import 'package:{{ package.name }}/{{ package.name }}.dart';
```

### `lib/src/` — Private Implementation Code

All of your actual implementation goes here. Files inside `lib/src/` are **private by default** — they are not accessible to package consumers unless you explicitly export them from the barrel file above.

Organize your code into logical files within this directory:

```
lib/src/
├── models/                         # Data models
├── utils/                          # Helper functions and utilities
└── exceptions.dart                 # Custom exception classes
```

A starting implementation file might look like:

```dart
// lib/src/{{ package.name }}_base.dart

/// A base class for {{ package.name }}.
class MyPackageClass {
  // Your implementation here.
}
```

**Key rules for `lib/src/`:**

- Any file you want consumers to access must be exported in `lib/{{ package.name }}.dart`.
- Anything not exported stays internal — use this to hide implementation details.
- Keep each file focused on a single concern.

### `test/` — Unit Tests

Every public class, function, and behavior in your package should have corresponding tests here. Test files should mirror the structure of `lib/src/` and end with `_test.dart`.

```
test/
├── {{ package.name }}_test.dart           # Top-level or general tests
├── models/
│   └── some_model_test.dart
└── utils/
    └── some_util_test.dart
```

A minimal test file:

```dart
// test/{{ package.name }}_test.dart

import 'package:{{ package.name }}/{{ package.name }}.dart';
import 'package:test/test.dart';

void main() {
  group('MyPackageClass', () {
    test('should do something', () {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

Run tests with:

```bash
flutter test
```

### `example/` — Usage Examples

Provide a runnable example that demonstrates how to use your package. This is what appears on the "Example" tab if you publish to pub.dev.

```dart
// example/{{ package.name }}_example.dart

import 'package:{{ package.name }}/{{ package.name }}.dart';

void main() {
  // Demonstrate basic usage of the package here.
}
```

### `pubspec.yaml` — Package Configuration

This defines your package metadata, dependencies, and SDK constraints.

### `analysis_options.yaml` — Lint Rules

Controls static analysis and lint rules for the package.

### `CHANGELOG.md` — Version History

Automatically generated and updated by the CI/CD pipeline based on conventional commit messages. Do not manually edit this file.

### `LICENSE`

Include the license text for your chosen license (MIT, BSD-3, Apache 2.0, etc.).

---

## Publishing Setup

Before the CI/CD workflows can automatically publish your package, you need to complete a one-time setup to connect your GitHub repo to pub.dev. This involves three steps: an initial manual publish, configuring pub.dev, and setting up the GitHub environment.

### Step 1: Initial Publish from Local

The first publish must be done manually from your local machine to register the package on pub.dev.

```bash
dart pub publish
```

Follow the prompts to authenticate and confirm. This establishes the package on pub.dev under your personal account.

### Step 2: Configure pub.dev

Once the package is live on pub.dev, go to the **Admin** tab for your package at `https://pub.dev/packages/{{ package.name }}/admin` and make the following changes:

1. **Transfer ownership to the publisher:** Under the "Publisher" section, migrate the package to the `resengi.io` verified publisher. This ensures the package is branded under the org rather than a personal account.

2. **Enable automated publishing from GitHub:** Under the "Automated publishing" section, enable publishing from GitHub. Configure it with:
   - **Repository:** `resengi/{{ package.name }}`
   - **Environment:** `pub.dev`

This tells pub.dev to trust publish requests that come from GitHub Actions running in that specific repo and environment.

### Step 3: Set Up the GitHub Environment

On your GitHub repo, go to **Settings → Environments** and create a new environment named `pub.dev`. This environment name must match exactly what you configured on pub.dev in the previous step.

You can optionally configure the environment with protection rules such as required reviewers or limiting deployment to specific branches (e.g., `main` only), but the environment must exist for the OIDC token exchange between GitHub Actions and pub.dev to work.

Once this is in place, the `publish.yml` and `release.yml` workflows in `.github/workflows/` will be able to publish new versions to pub.dev automatically when triggered.

---

## Development Workflow

1. **Add implementation code** in `lib/src/`.
2. **Export public APIs** from `lib/{{ package.name }}.dart`.
3. **Write tests** in `test/` for every public interface.
4. **Add dependencies** to `pubspec.yaml` as needed, then run `flutter pub get`.
5. **Update the example** in `example/` to reflect current usage.
6. **Run checks** before committing:
   ```bash
   flutter analyze        # Static analysis
   flutter test           # Run all tests
   dart format .          # Format code
   ```
7. **Use conventional commit messages** so the CI/CD pipeline can automatically update `CHANGELOG.md` and bump the version in `pubspec.yaml`. Follow standard semantic versioning prefixes:
   - `fix:` — patch release (e.g., `fix: handle null values in parser`)
   - `feat:` — minor release (e.g., `feat: add support for custom themes`)
   - `feat!:` or `BREAKING CHANGE:` — major release (e.g., `feat!: redesign public API`)