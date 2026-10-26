# Optional: build a signed bundle on GitHub and upload it to a Play track. Rename to release.yml to enable.
# Needs repository secrets: KEYSTORE_BASE64, STORE_PASSWORD, KEY_PASSWORD, PLAY_SERVICE_ACCOUNT_JSON
# (Play Console > Setup > API access > service account with "Release manager"). The FIRST upload of an app must be done by hand.
name: Release to Play (internal track)

on:
  push:
    tags: ["v*"]
  workflow_dispatch:

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 17 }
      - name: Restore upload keystore
        run: echo "$KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/upload.jks"
        env: { KEYSTORE_BASE64: "${{ secrets.KEYSTORE_BASE64 }}" }
      - name: Build bundle
        run: ./gradlew bundleRelease
        env:
          KEYSTORE_PATH: ${{ runner.temp }}/upload.jks
          STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
      - name: Upload to Play (internal testing)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: {{package}}
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: internal
          status: completed
