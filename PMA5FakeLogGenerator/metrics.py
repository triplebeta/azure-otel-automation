from run import Run
import logging
from typing import Iterable

# Open Telemetry
from opentelemetry import metrics
from opentelemetry.metrics import CallbackOptions, Observation, ObservableUpDownCounter
 
# Used sample from https://stackoverflow.com/questions/74804185/update-observablegauge-in-open-telemetry-python
# and https://github.com/Azure/azure-sdk-for-python/tree/main/sdk/monitor/azure-monitor-opentelemetry-exporter
# and https://github.com/microsoft/ApplicationInsights-Python/blob/main/azure-monitor-opentelemetry/samples/metrics/instruments.py
# Define the object to observe in the callback of the Gauge metric.
class ParallelRunsTracker:
    def __init__(self):
        self.activeRuns = [Run]
        
    def register_start_run(self, run: Run):
        self.activeRuns.append(run)

    def register_end_run(self, run: Run):
        self.activeRuns.remove(run)

    def get_active_run_count(self) -> int:
        return len(self.activeRuns)


# Not the best example of a gauge but it helps to show how to implement an observable metric
# TODO Instead of 1 value, return an array with the number of parallel runs per machine
def create_parallel_runs_observable_updown_counter(parallel_runs_tracker: ParallelRunsTracker) -> ObservableUpDownCounter:
    """ Create an async UpDown counter """
    def observable_updown_counter_func(options: CallbackOptions) -> Iterable[Observation]:
        active_run_count = parallel_runs_tracker.get_active_run_count()
        logging.info(f'Observable UpDown Counter: currently {active_run_count} runs going on.')
        yield Observation(active_run_count,{})

    return meter.create_observable_up_down_counter("tasks.runs.parallel", [observable_updown_counter_func],description="Number of parallel runs going on.")


# Create metrics. unit must be one of the values from the UCUM, see: https://ucum.org/ucum
# Types of telemetry, https://www.timescale.com/blog/a-deep-dive-into-open-telemetry-metrics/
# The "observable" metrics are asynchronous. Important difference: they should NOT report delta values but absolute values. The framework will convert then them to deltas.
# Counter: delta's, only increasing
# Gauge: data you would not want to sum but might want to avg or use max.
meter = metrics.get_meter_provider().get_meter(__name__)
metric_batch = meter.create_counter(name="tasks.batches", description="Count of batches processed for a machine.")

# Metrics for the runs
metric_run = meter.create_counter(name="tasks.runs", description="Count all runs for a machine, incl. retries.")
metric_retried_run = meter.create_counter(name="tasks.runs.retried", description="Count only of retry-runs for a machine.")
metric_failed_run = meter.create_counter(name="tasks.runs.failed", description="Count failed runs for a machine.")
metric_completed_run = meter.create_counter(name="tasks.runs.completed", description="Count successfully completed runs for a machine.")

# Metrics for the tasks
metric_tasks_count = meter.create_counter(name="tasks.count", description="Count of successfully created tasks.")
