# Logs Management

This document illustrates how XCMetrics manages the logs on the machine where builds are performed.
The goal of XCMetrics (the tool being executed in a post-action scheme) is to fetch logs from Xcode's directory, cache them and perform the upload to the backend service for later parsing and processing.

## Cache Management

In order not to interfere with Xcode's build logs directory (`~/Library/Developer/Xcode/DerivedData/ProjectName-svojrqwbcsautrwqbobafsapoqwe/Logs/Build/`), we copy the logs to a separate cache directory that we can completely manage ourselves. 
The directory is `~/Library/Caches/xcmetrics`, where logs are placed in different namespaced directories based on the criteria described below. This is a possible layout of the cache directory:

```
XCMetrics/
├── Project1/
│   ├── 0A391ECA-8B35-4E81-865E-FB6D43861384.xcactivitylog
│   ├── 8F069C22-27FA-4479-AF3C-9674677FC20D_UPLOADED.xcactivitylog
│   └── requests/
│       └── 814B2B39-1E50-4953-992C-AE94982D5B9A
└── Project2/
    └── 0BBA9976-4EBB-484F-A276-C97A62AB90F2.xcactivitylog
```

Let's break it down:

- At the top level, we have a directory for each project. If this directory doesn't exist, for example the first time `XCMetrics` is run in a new project, it will be automatically created. This allows XCMetrics to be used in multiple projects on the same machine, and avoid logs to conflict with each other.
- Logs are copied from Xcode's directory to the project directory. If a log has been successfully uploaded on the first try, `_UPLOADED` will be appended to its file name. This is done in order to keep track which logs have been cached already. 
- If a log fails to upload (i.e: the backend service is not reachable), the request is written to the `requests` directory as a binary object containing the log itself along with all the metadata collected for that build. The original `xcactivitylog` is renamed with `_UPLOADED` and then the request object will be automatically retried on the next run.

The following diagram better illustrates the flow of all the steps.

![Cache Management](img/cache-management.jpg)

Xcode sometimes takes a few seconds to write the full log to disk, so XCMetrics can optionally wait for some time in order to always try and fetch the latest log (use the argument `--timeout` to customize this behavior).

## Visual Demo

The following GIF shows the behavior when the upload is successful. As you can see, the log is cached in the `XCMetrics` directory and marked as uploaded.

![Upload Successful](img/upload-successful.gif)

In case internet connectivity is absent or some other during the upload occurs, the log is marked as uploaded and cached offline for retry during the next run.

![Upload Failed](img/upload-failed.gif)
