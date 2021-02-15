<!-- ![Build Status](docs/img/logo.png) -->
<p align="center">
    <img src="docs/img/logo.png" width="75%">
</p>

_XCMetrics is the easiest way to collect Xcode builds metrics and improve your developer productivity._

[![Build Status](https://github.com/spotify/XCMetrics/workflows/CI/badge.svg)](https://github.com/spotify/XCMetrics/workflows/CI/badge.svg)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Docker image](https://img.shields.io/docker/pulls/spotify/xcmetrics.svg)](https://hub.docker.com/r/spotify/xcmetrics)
[![Slack](https://slackin.spotify.com/badge.svg)](https://slackin.spotify.com)

## Overview

- 📈 Keep your build times under control and monitor which targets are taking the longest to compile.
- ⚠️ Collect warnings to improve your code health.
- ❌ Collect errors to help and diagnose builds problems in real-time.
- 🛠 Build custom plugins to collect an infinite amount of metadata to be attached to each build, such as version control information and thermal throttling.

XCMetrics is built on top of [XCLogParser](https://github.com/spotify/XCLogParser), which is a tool that can parse Xcode and xcodebuild logs stored in the xcactivitylog format. This allows XCMetrics to collect accurate metrics for you to review and keep track during the lifetime of a codebase.
XCMetrics has collected almost 1 million builds and over 10 billion steps from all Spotify iOS applications since its introduction. It has allowed us to make important and informed decision in regards to our project structure and architecture.

## Getting Started

Head over to our [Getting Started docs](docs/Getting%20Started.md) to see how to integrate XCMetrics in your project.

## Develop

XCMetrics is built using Swift Package Manager, you just need to open the `Package.swift` file in Xcode: 

```bash
xed Package.swift
```

## Support

Create a [new issue](https://github.com/spotify/XCMetrics/issues/new) with as many details as possible. It's important that you follow the issue template and include all required information in order for us to get back to you as soon as possible.

Reach us at the `#xcmetrics` channel in [Slack](https://slackin.spotify.com/).

## Contributing

We feel that a welcoming community is important and we ask that you follow Spotify's 
[Open Source Code of Conduct](https://github.com/spotify/code-of-conduct/blob/master/code-of-conduct.md)
in all interactions with the community.

## Authors

A full list of [contributors](https://github.com/spotify/XCMetrics/graphs/contributors?type=a) can be found on GitHub.

Follow [@SpotifyEng](https://twitter.com/spotifyeng) on Spotify for updates.

## License

Copyright 2020 Spotify, Inc.

Licensed under the Apache License, Version 2.0: https://www.apache.org/licenses/LICENSE-2.0

This product includes software developed by the "Marcin Krzyzanowski" (http://krzyzanowskim.com/).

## Security Issues?

Please report sensitive security issues via [Spotify's bug-bounty program](https://hackerone.com/spotify) rather than GitHub.
