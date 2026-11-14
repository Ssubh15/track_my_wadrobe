# Build and install on an iPhone

Wardrobe is built in GitHub Actions because iOS builds require macOS and Xcode. Every push to `main` and every pull request runs the workflow in `.github/workflows/ios.yml`. It generates the Xcode project, runs the unit tests on an available iPhone simulator, builds for a generic iOS device with code signing disabled, packages `Wardrobe.app` as `Wardrobe.ipa`, and uploads the IPA as the **`wardrobe-ipa`** artifact. The workflow fails if the IPA is missing.

## Download the IPA

1. Push a change to `main` and open the repository's **Actions** tab.
2. Open the completed **iOS** workflow run. Wait for the `build-and-test` job to succeed.
3. In the run's **Artifacts** section, download **`wardrobe-ipa`**.
4. Unzip GitHub's artifact download. It contains `Wardrobe.ipa`.

The artifact is deliberately unsigned. It cannot be installed by tapping it; a sideloading tool signs it with your Apple ID first.

## Install with Sideloadly on Windows

1. Install [Sideloadly](https://sideloadly.io/) and its required Apple device support software.
2. Unzip the downloaded **`wardrobe-ipa`** artifact and locate `Wardrobe.ipa`.
3. Connect and unlock the iPhone, then trust the computer if iOS asks.
4. Open Sideloadly, select the connected iPhone, and drag `Wardrobe.ipa` into the IPA field.
5. Enter the Apple ID used for signing. If prompted, use an app-specific password, then start installation.
6. If iOS asks, open **Settings > General > VPN & Device Management**, select the Apple ID profile, and trust it.

## Install with AltStore on Windows

1. Install [AltServer/AltStore](https://altstore.io/) and its Apple device-support requirements.
2. Connect the iPhone, start AltServer, and install AltStore on the phone according to AltStore's instructions.
3. Open AltStore on the iPhone, choose **My Apps**, tap **+**, and select `Wardrobe.ipa` from Files.
4. Sign in with the Apple ID you want to use for free signing and wait for installation to finish.
5. Trust the developer profile in **Settings > General > VPN & Device Management** if iOS asks.

## Free Apple ID limitations

- Free-signed apps usually expire after seven days. Reinstall or refresh Wardrobe before it expires.
- Apple limits the number of active free-signed apps. The current limit and refresh behavior are controlled by Apple and may change.
- CloudKit sync and Sign in with Apple require paid Apple Developer Program setup. Wardrobe's local functionality should remain usable without them.
- Do not share an IPA that has been signed with your Apple ID. The workflow artifact is unsigned and is the appropriate file to share privately for separate signing.
