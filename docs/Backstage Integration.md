# Backstage Integration

The XCMetrics Backstage plugin offers a great way to visually analyze and inspect
the metrics collected by XCMetrics. To use it, simply
[install the plugin](https://github.com/backstage/backstage/tree/master/plugins/xcmetrics)
to your instance of Backstage and navigate to `https://<your-backstage-url>/xcmetrics`.


## Turn on the Scheduled Jobs

The Backstage plugin needs aggregated data that is computed every day. To do this, we are using Vapor's Scheduled Jobs support and you will need to enable it in your Backend deployment.

For doing that, you need to:

1. Start the backend with the `--scheduled` flags.
2. Pass the Environment Variable `XCMETRICS_SCHEDULE_STATISTICS_JOBS` with the value "1":

Example:

```bash
XCMETRICS_SCHEDULE_STATISTICS_JOBS=1 ./XCMetricsBackend queues --scheduled --env production
```

Is important to note, that is not recommended to start more than one instance of the backend with to run the scheduled jobs because the same job may run in all of them causing some issues in the data that is computed by them. You can see an example of how to configure a single instance with the responsibility to run the job in [this example](../DeploymentExamples/MultiInstances/xcmetrics-scheduled-jobs-deployment.yaml).
