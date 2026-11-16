# MP 7 Protocol (locked before any LLM runs)

- Track: VDB/Structured, CIS 731 (team composition: [confirm])
- Dataset: IEEE-CIS Fraud Detection (Kaggle)
- Label space: {legitimate, fraud}, binary, 
- Target: isFraud (0 -> legitimate, 1 -> fraud)
- Eval source: [time-held-out slice of train_transaction, pending instructor confirmation of eval_mp7.jsonl]
- Feature subset: [list, justified]
- Model: Qwen/Qwen2.5-1.5B-Instruct, revision [hash]
- Shot sweep: k in {0, 1, 3, 5, 8}; k=1 cannot be class-balanced and is reported separately
- Seeds: 42, 123, 456, 789, 2026
- Demonstration orderings per seed: [original, reversed, one random permutation]
- Metric: macro-F1 with percentile bootstrap 95% CI, 10,000 resamples
- Graded metrics: compute_graded_metric only; compute_dev_metric is advisory
- Committed: [commit hash, date]


# MP 7 Protocol: Few-Shot Trope/Genre Classification (Fraud Variant)

**Status:** Locked before any model results are generated.
**Committed:** [commit hash], [date and time CST]
**Team:** Genesis Joseph, Tatenda. Team composition: CIS 731 (entirely graduate).
**Due date:** [new due date from extension, in writing]

---

## 1. Dataset and Source Status

- **Dataset:** IEEE-CIS Fraud Detection (Kaggle), training split only. Source identifier `ieee-fraud-detection`. Extraction date 10/11/2026.
- **Table:** `workspace.default.ieee_train_merged`, the left join of `train_transaction` and `train_identity` on `TransactionID`. Rows: 590,540.
- **Dataset approval:** Approved by [professor name], [date], in writing (attached as `approvals/dataset_approval.pdf`).
- **Test-split status:** Kaggle's `test_transaction.csv` has no labels and is not used.
- **Graded eval source:** None. The instructor did not provide `eval_mp7.jsonl`.
- **Evaluation source used:** A self-built, time-held-out test partition (Section 4). **All metrics in this report are dev, advisory.** They are not `compute_graded_metric` results. This is a disclosed substitution.

## 2. Label Space and Exception

- **Label set:** `{legitimate, fraud}`, binary.
- **Target:** `isFraud` (0 → `legitimate`, 1 → `fraud`).
- **Spec deviation:** MP 7 specifies 8–12 labels. The binary label set was approved by [professor name], [date], in writing (attached as `approvals/label_exception.pdf`).
- **Verbalizers:** `" legitimate"` and `" fraud"`, with the leading space. Both must tokenize to distinct first tokens under the pinned LLM tokenizer. The pipeline asserts this.

## 3. Experimental Design

### 3.1 Shot sweep and exemplar definition
- **k ∈ {0, 1, 3, 5, 8}**, defined as the **total number of labeled exemplars** per configuration, for all three classifiers.
- Exemplars are balanced across classes as evenly as possible. For odd k, the extra exemplar goes to the class chosen by seed parity. For k=1 this is 1 vs. 0, which is unbalanced by design, so **k=1 is reported separately** and excluded from the balanced comparison.
- **k=0** applies to the LLM only (zero-shot). Prototype and kNN are reported as "n/a" at k=0.

### 3.2 Seeds
- **Seeds:** 42, 123, 456, 789, 2026 (five seeds).
- Seeds control exemplar sampling, demonstration ordering (random permutation), and the LLM evaluation sample. They do not control the train/validation/test split, which is deterministic by time.

### 3.3 Demonstration ordering (LLM only)
- Three orderings per seed and per k ≥ 1: `original`, `reversed`, and `random` (permutation seeded by seed+1).
- Each k ≥ 1 is run under all three orderings. The reported spread across orderings is the position-bias measure.

### 3.4 Classifiers (one `Classifier` interface)
1. **Prototype:** Normalized class-mean of exemplar embeddings. Score is a softmax over cosine similarities with **fixed temperature 10**, set before results and not changed afterward.
2. **kNN:** Top-2k neighbors from a FAISS `IndexFlatIP` built over the exemplar set, weighted by similarity. Score is the weighted fraction of fraud neighbors.
3. **Few-shot LLM:** `Qwen/Qwen2.5-1.5B-Instruct`, revision **[hash]**. Chat-formatted demonstrations as user/assistant turns. Classification by **rank over the two verbalizers** (argmax of the first-token logits, softmax over the pair). Output cannot be a label outside the set by construction.
- **Decision threshold:** 0.5 on the score, for all three classifiers. Not tuned.

### 3.5 Contracts
- `predict_proba` returns a non-negative array that sums to 1 within 1e-6 and whose labels lie inside the declared set. Checked with `deal`.

## 4. Data Partitions

- **Split key:** `TransactionDT`, sorted ascending. No shuffling.
- **Proportions:** train 80%, validation 15%, test 5%.
- **Cutoffs:**
  - `TRAIN_END` = [80th percentile of TransactionDT, value]
  - `VAL_END` = [95th percentile of TransactionDT, value]
- **Partition sizes and fraud rates (filled from data before any model run):**

| Partition | Rows | Fraud count | Fraud rate |
|---|---|---|---|
| train | [ ] | [ ] | [ ] |
| validation | [ ] | [ ] | [ ] |
| test | [ ] | [ ] | [ ] |

- **Rule:** Any difference in fraud rate across partitions is reported as a limitation.

### 4.1 Use of each partition
- **Train:** Exemplar pool, FAISS index, and feature-ranking fit.
- **Validation:** Prompt wording, parser and verbalizer checks, and feature selection. Not used for any reported metric.
- **Test:** Evaluation only. Each configuration is evaluated once. Test-set results are not used to change any decision in this protocol.

### 4.2 Feature selection
- **Candidate features (25):** DeviceInfo, TransactionAmt, id_31, P_emaildomain, C1, C13, C14, card1, D2, addr1, R_emaildomain, card2, C11, id_30, card6, id_33, card3, D15, card5, dist1, D8, V45, C6, C2, D4.
- **Ranking method:** [To be completed.] Fit LightGBM on the **train partition only**. Rank by **permutation importance on the validation partition** with `average_precision`, `n_repeats=10`, `random_state=42`.
- **Prompt subset:** The top 10 from the ranking above. Embeddings and kNN use the same 10 features, for comparability.
- **Disclosed exploratory run:** A prior LightGBM importance ranking computed on the full dataset, including the test partition, was reviewed during planning. **It was not used for selection.** The top 10 of that run was [matches / differs] from the protocol's final list. This is disclosed as a potential leak that was avoided.
- **Current status:** The feature list is **provisional**. It will be replaced by the train-only permutation ranking before any LLM run. If the ranking changes the list, this section and `FEATURES` in the config are updated and committed first.

## 5. Serialization

- **Format:** `col=value | col=value | ...` in the fixed order of the final feature list. Same format for exemplars, validation, and test.
- **Missingness:** Null and blank/whitespace strings become `unknown`. Numeric nulls are not zero-filled.
- **Bucketing (high-cardinality fields: DeviceInfo, id_31, P_emaildomain, R_emaildomain, card1):** Top 20 values by train frequency are kept. Everything else becomes `other`. The bucket map is fit on train only.
- **Numeric rounding:** Two decimal places.
- **Leakage controls:**
  - No `TransactionID`, `TransactionDT`, or partition label appears in the serialized text.
  - No verbalizer string (`legitimate`, `fraud`) appears in any feature value. Check at build time.
  - Exact duplicates between exemplars and evaluation rows are removed from the evaluation set.

## 6. Evaluation Sample and Compute Budget

- **Non-LLM classifiers (prototype, kNN):** Evaluated on the **full test partition**.
- **LLM classifier:** Evaluated on a **stratified sample of the test partition**, `n = 400`, drawn once with seed 42 and saved to `llm_eval_sample.parquet`. The non-LLM classifiers are also reported on this same sample so the head-to-head comparison is like for like.
- **Reason:** CPU inference of a 1.5B model over 75 LLM configurations on the full test partition exceeds the compute budget.
- **Quota log:** [Recorded in `quota_log.md`. Tokens and wall-clock time per configuration.]

## 7. Metrics and Uncertainty

- **Primary metric:** Macro-F1 over `{legitimate, fraud}`.
- **Secondary:** Per-class precision and recall at the best configuration. Accuracy is reported only with the all-`legitimate` baseline next to it, because fraud is rare.
- **Baseline:** Predict `legitimate` for every row, evaluated on the same rows. Reported as the floor.
- **Seed and ordering summary:** Mean and standard deviation of macro-F1 over the five seeds, per classifier and k. For the LLM, the ordering spread is reported separately.
- **Confidence intervals:** Percentile bootstrap, 95%, **10,000 resamples**, resampling **evaluation rows with replacement**. The CI is computed on the predictions of one seed and ordering per configuration, and the seed spread is reported alongside it. `bootstrap seed = 0`.
- **Significance tests and calibration:** Deferred to MP 10. Not claimed in MP 7.
- **Status label:** Every table and figure header reads **"dev, advisory"**.

## 8. Reproducibility

- **Environment:** Pinned DevContainer, [image digest]. CPU only. No GPU is used or required.
- **Packages:** [lockfile hash].
- **Models:**
  - Embedding: `jinaai/jina-embeddings-v2-base-en`, revision [hash]
  - LLM: `Qwen/Qwen2.5-1.5B-Instruct`, revision [hash]
- **Random seeds:** As in Section 3.2.
- **Outputs:** `predictions.jsonl` with one row per (classifier, k, seed, ordering, row). Fields: `method, k, seed, ordering, row, y_true, p_fraud, y_pred`.

## 9. Deviations from the Spec (disclosed)

| Spec requirement | Protocol | Reason |
|---|---|---|
| 8–12 label space | Binary `{legitimate, fraud}` | Professor's written approval (Section 2) |
| Graded eval set `eval_mp7.jsonl` | Self-built time-held-out test partition, advisory | Instructor did not provide it |
| Full-test-set LLM evaluation | 400-row stratified sample | CPU compute budget (Section 6) |
| Feature selection (unspecified) | Train-only permutation ranking, top 10 | Avoids test leakage (Section 4.2) |

## 10. Change Log

| Version | Date | Change |
|---|---|---|
| 1.0 | [date] | Initial lock before results |