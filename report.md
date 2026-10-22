# MP5 Submission Report

## Schema and Contracts

The project uses the IEEE-CIS Fraud Detection dataset in Databricks. The structured replay reads Parquet records from `/Volumes/workspace/default/ieee_fraud_bronze/mp5_landing`. The streaming and fault-tolerance queries use `TransactionID`, `TransactionAmt`, `isFraud`, and `event_ts`.

The input `StructType` is:

```python
STREAM_SCHEMA = StructType([
    StructField("TransactionID", LongType(), True),
    StructField("TransactionAmt", DoubleType(), True),
    StructField("isFraud", IntegerType(), False),
    StructField("event_ts", TimestampType(), True),
])
```

The pipeline applies the following data contracts

1. **BoundedChunking:** Each record must satisfy `ts_start <= ts_end` and the configured chunk-duration bound. Because a transaction is modeled as a point event, the adaptation uses `ts_start == ts_end` and a duration of zero.
2. **Provenance (INV-10):** Required provenance identifiers must be present, and `source_id` must belong to the admitted source whitelist when one is configured.
3. **Label validity:** Training records must have a non-null `is_fraud` value in `{0, 1}`. Test records must not be assigned ground-truth fraud labels.
4. **Uniqueness:** `transaction_id` must be non-null and unique within the applicable dataset or split.
5. **Schema and required fields:** Records must conform to the declared schema, and fields designated as required must be present. Nullability choices are verified against the full Bronze tables.

## Watermark and State Analysis

Event time is derived from `TransactionDT`, a relative offset rather than an absolute timestamp, using the documented anchor `2017-12-01T00:00:00Z`. The anchor is a modeling assumption. The replay’s ingestion timestamps do not represent naturally arriving production events.

The 40-record lateness sample produced:

| Metric | Observed value |
|---|---:|
| p50 lateness | -83 seconds |
| p95 lateness | 1 second |
| p99 lateness | 1 second |
| Negative-lateness records | 30 |

These statistics describe the synthetic replay sample, not production traffic. The chosen watermark delay is **60 seconds**
The window aggregations use **append mode**, emitting completed windows after the watermark passes their end. State retention depends on event-time progress, watermark delay, window duration, key cardinality, and arrival rate. The sliding window overlaps five one-minute intervals per event, while the tumbling window uses 60 second intervals.

## Query Design

The intended aggregations are a 60-second tumbling window and a five-minute sliding window with a one-minute slide. The required outputs include record count, approximate distinct token count, top-10 terms, and mean ingestion latency. The Parquet sinks use separate output paths and checkpoint locations for each query.

The implemented IEEE-CIS fault-test aggregation computes transaction count, total transaction amount, and fraud count per 60-second window. 

The sinks are append-mode Parquet outputs. Each streaming query must use its own checkpoint directory. The structured replay source is the landing directory under `/Volumes/workspace/default/ieee_fraud_bronze/mp5_landing`.

## Fault-Tolerance Reconciliation

The fault test used the same Parquet input, output path, and checkpoint location across the initial run, interruption, and restart. The query was stopped after approximately 18 seconds while active; this was a graceful stop, not a forced process crash. It was then restarted with `availableNow=True` and the existing checkpoint.

The input contained 40 records, with four expected tumbling windows:

| Window | Expected records | Observed after restart |
|---|---:|---|
| 03:09–03:10 | 10 | Present |
| 03:10–03:11 | 10 | Present |
| 03:11–03:12 | 10 | Missing |
| 03:12–03:13 | 10 | Missing |

The output contained **2 rows, 2 distinct window keys, 0 duplicate window keys**, rather than all four expected windows. A second restart with the same checkpoint and output path left the output at two rows. Therefore, this experiment did **not** establish successful end-to-end reconciliation: two expected windows remain missing from the observed output.


**Environment:** Databricks workspace

