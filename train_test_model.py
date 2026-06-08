from __future__ import annotations

import bisect
import csv
import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from sklearn.ensemble import ExtraTreesClassifier, RandomForestClassifier
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    accuracy_score,
    balanced_accuracy_score,
    confusion_matrix,
    roc_auc_score,
    roc_curve,
)


DATASET_PATH = Path("datasets") / "dataset_growth_1y_10b.csv"
OUTPUT_DIR = Path("model_outputs")

TRAIN_START_DATE = "2010-01-01"
TRAIN_END_DATE = "2014-12-31"
TEST_START_DATE = "2015-01-01"
TEST_END_DATE = "2020-12-31"
TARGET_TAIL_FRACTION = 0.15

ENSEMBLE_WEIGHTS = {
    "random_forest": 0.8,
    "extra_trees": 0.2,
}

RANK_FEATURE_SPECS = {
    "revenue_growth_qoq": "high",
    "revenue_growth_yoy": "high",
    "earnings_yield": "high",
    "sales_yield": "high",
    "book_yield": "high",
    "free_cash_flow_yield": "high",
    "ev_sales_yield": "high",
    "return_on_assets": "high",
    "return_on_common_equity": "high",
    "return_on_invested_capital": "high",
    "current_ratio": "high",
    "cash_ratio": "high",
    "quick_ratio": "high",
    "total_debt_to_ebitda": "low",
    "market_cap_log": "high",
}

FLAG_FEATURE_COLUMNS = [
    "revenue_growing_qoq_flag",
    "revenue_growing_yoy_flag",
    "pe_reasonable_flag",
    "price_to_sales_reasonable_flag",
    "price_to_book_reasonable_flag",
    "ev_to_sales_reasonable_flag",
    "price_to_fcf_reasonable_flag",
    "not_overvalued_score",
]

FEATURE_COLUMNS = FLAG_FEATURE_COLUMNS + [
    f"{feature}_rank" for feature in RANK_FEATURE_SPECS
]


@dataclass
class PreparedDataset:
    train_rows: list[dict[str, str]]
    test_rows: list[dict[str, str]]
    x_train: np.ndarray
    y_train: np.ndarray
    x_test: np.ndarray
    y_test: np.ndarray
    medians: dict[str, float]
    lower_bounds: list[float]
    upper_bounds: list[float]


def parse_float(value: str | None) -> float | None:
    if value is None:
        return None
    text = value.strip()
    if text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def load_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(
            f"Dataset not found: {path}. Run build_dataset.py first."
        )

    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            if parse_float(row.get("target_return")) is not None:
                rows.append(row)

    rows.sort(key=lambda row: row["report_date"])
    return rows


def add_quarter_rank_features(rows: list[dict[str, str]]) -> None:
    for feature_name, direction in RANK_FEATURE_SPECS.items():
        grouped_values: dict[str, list[float]] = {}
        for row in rows:
            value = parse_float(row.get(feature_name))
            if value is None:
                continue
            grouped_values.setdefault(row["entry_quarter"], []).append(value)

        sorted_grouped_values = {
            quarter_key: sorted(values)
            for quarter_key, values in grouped_values.items()
        }

        rank_feature_name = f"{feature_name}_rank"
        for row in rows:
            value = parse_float(row.get(feature_name))
            values = sorted_grouped_values.get(row["entry_quarter"])
            if value is None or not values:
                row[rank_feature_name] = ""
                continue

            if len(values) == 1:
                rank = 0.5
            else:
                position = bisect.bisect_right(values, value) - 1
                rank = position / (len(values) - 1)

            if direction == "low":
                rank = 1.0 - rank
            row[rank_feature_name] = f"{rank:.10f}"


def assign_tail_targets(rows: list[dict[str, str]], tail_fraction: float) -> list[dict[str, str]]:
    grouped_rows: defaultdict[str, list[tuple[float, dict[str, str]]]] = defaultdict(list)
    for row in rows:
        grouped_rows[row["entry_quarter"]].append((float(row["target_return"]), row))

    labeled_rows: list[dict[str, str]] = []
    for items in grouped_rows.values():
        items.sort(key=lambda item: item[0])
        tail_count = max(1, int(len(items) * tail_fraction))

        for _, row in items[:tail_count]:
            row["target_class"] = "0"
            labeled_rows.append(row)
        for _, row in items[-tail_count:]:
            row["target_class"] = "1"
            labeled_rows.append(row)

    labeled_rows.sort(key=lambda row: row["report_date"])
    return labeled_rows


def compute_median(values: list[float]) -> float:
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2.0


def prepare_dataset(rows: list[dict[str, str]]) -> PreparedDataset:
    train_rows = [
        row
        for row in rows
        if TRAIN_START_DATE <= row["report_date"] <= TRAIN_END_DATE
    ]
    test_rows = [
        row
        for row in rows
        if TEST_START_DATE <= row["report_date"] <= TEST_END_DATE
    ]

    if len(train_rows) < 500:
        raise RuntimeError("Too few training rows.")
    if len(test_rows) < 500:
        raise RuntimeError("Too few test rows.")

    medians: dict[str, float] = {}
    for feature in FEATURE_COLUMNS:
        values = [parse_float(row.get(feature)) for row in train_rows]
        present = [value for value in values if value is not None]
        medians[feature] = compute_median(present) if present else 0.0

    def build_matrix(source_rows: list[dict[str, str]]) -> tuple[np.ndarray, np.ndarray]:
        feature_rows: list[list[float]] = []
        targets: list[int] = []
        for row in source_rows:
            feature_rows.append(
                [
                    value if (value := parse_float(row.get(feature))) is not None else medians[feature]
                    for feature in FEATURE_COLUMNS
                ]
            )
            targets.append(int(row["target_class"]))
        return np.array(feature_rows, dtype=float), np.array(targets, dtype=int)

    x_train, y_train = build_matrix(train_rows)
    x_test, y_test = build_matrix(test_rows)

    lower_bounds = np.percentile(x_train, 1, axis=0)
    upper_bounds = np.percentile(x_train, 99, axis=0)
    x_train = np.clip(x_train, lower_bounds, upper_bounds)
    x_test = np.clip(x_test, lower_bounds, upper_bounds)

    return PreparedDataset(
        train_rows=train_rows,
        test_rows=test_rows,
        x_train=x_train,
        y_train=y_train,
        x_test=x_test,
        y_test=y_test,
        medians=medians,
        lower_bounds=lower_bounds.tolist(),
        upper_bounds=upper_bounds.tolist(),
    )


def build_models() -> dict[str, object]:
    return {
        "random_forest": RandomForestClassifier(
            n_estimators=600,
            max_depth=12,
            min_samples_leaf=8,
            n_jobs=-1,
            class_weight="balanced_subsample",
            random_state=42,
        ),
        "extra_trees": ExtraTreesClassifier(
            n_estimators=700,
            max_depth=14,
            min_samples_leaf=6,
            n_jobs=-1,
            class_weight="balanced_subsample",
            random_state=42,
        ),
    }


def compute_metrics(y_true: np.ndarray, probabilities: np.ndarray) -> tuple[np.ndarray, dict[str, float]]:
    predicted_labels = (probabilities >= 0.5).astype(int)
    metrics = {
        "accuracy": float(accuracy_score(y_true, predicted_labels)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, predicted_labels)),
        "roc_auc": float(roc_auc_score(y_true, probabilities)),
    }
    return predicted_labels, metrics


def train_models(prepared: PreparedDataset) -> tuple[dict[str, dict[str, float]], dict[str, np.ndarray], dict[str, object]]:
    metrics: dict[str, dict[str, float]] = {}
    probabilities: dict[str, np.ndarray] = {}
    models = build_models()

    for model_name, model in models.items():
        model.fit(prepared.x_train, prepared.y_train)
        model_probabilities = model.predict_proba(prepared.x_test)[:, 1]
        _, model_metrics = compute_metrics(prepared.y_test, model_probabilities)
        metrics[model_name] = model_metrics
        probabilities[model_name] = model_probabilities

    ensemble_probabilities = sum(
        ENSEMBLE_WEIGHTS[model_name] * probabilities[model_name]
        for model_name in ENSEMBLE_WEIGHTS
    )
    _, ensemble_metrics = compute_metrics(prepared.y_test, ensemble_probabilities)
    metrics["weighted_ensemble"] = ensemble_metrics
    probabilities["weighted_ensemble"] = ensemble_probabilities

    return metrics, probabilities, models


def compute_weighted_feature_importance(models: dict[str, object]) -> list[tuple[str, float]]:
    importances = np.zeros(len(FEATURE_COLUMNS), dtype=float)
    for model_name, weight in ENSEMBLE_WEIGHTS.items():
        importances += weight * models[model_name].feature_importances_

    result = list(zip(FEATURE_COLUMNS, importances.tolist(), strict=True))
    result.sort(key=lambda item: item[1], reverse=True)
    return result


def save_outputs(
    metrics: dict[str, dict[str, float]],
    probabilities: dict[str, np.ndarray],
    prepared: PreparedDataset,
    feature_importance: list[tuple[str, float]],
) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    predicted_labels, _ = compute_metrics(
        prepared.y_test,
        probabilities["weighted_ensemble"],
    )

    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "dataset_path": str(DATASET_PATH),
        "train_start_date": TRAIN_START_DATE,
        "train_end_date": TRAIN_END_DATE,
        "test_start_date": TEST_START_DATE,
        "test_end_date": TEST_END_DATE,
        "target_tail_fraction": TARGET_TAIL_FRACTION,
        "train_rows": len(prepared.train_rows),
        "test_rows": len(prepared.test_rows),
        "ensemble_weights": ENSEMBLE_WEIGHTS,
        "metrics": metrics,
        "top_features": [
            {"feature": feature, "importance": importance}
            for feature, importance in feature_importance[:15]
        ],
    }
    (OUTPUT_DIR / "best_model_metrics.json").write_text(
        json.dumps(payload, indent=2),
        encoding="utf-8",
    )

    with (OUTPUT_DIR / "feature_importance.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["feature", "importance"])
        writer.writerows(feature_importance)

    with (OUTPUT_DIR / "ensemble_predictions.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "exchange_code",
                "ticker",
                "report_date",
                "target_class",
                "target_return",
                "predicted_label",
                "predicted_probability",
            ]
        )
        for row, probability, label in zip(
            prepared.test_rows,
            probabilities["weighted_ensemble"],
            predicted_labels,
            strict=True,
        ):
            writer.writerow(
                [
                    row["exchange_code"],
                    row["ticker"],
                    row["report_date"],
                    row["target_class"],
                    row["target_return"],
                    int(label),
                    f"{float(probability):.10f}",
                ]
            )


def plot_results(
    metrics: dict[str, dict[str, float]],
    probabilities: dict[str, np.ndarray],
    prepared: PreparedDataset,
    feature_importance: list[tuple[str, float]],
) -> None:
    ensemble_probabilities = probabilities["weighted_ensemble"]
    ensemble_labels, _ = compute_metrics(prepared.y_test, ensemble_probabilities)

    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle("Large-cap 1Y Return Classification", fontsize=16)

    model_names = list(metrics)
    roc_auc_values = [metrics[name]["roc_auc"] for name in model_names]
    accuracy_values = [metrics[name]["accuracy"] for name in model_names]

    x_positions = np.arange(len(model_names))
    axes[0, 0].bar(x_positions - 0.18, roc_auc_values, width=0.36, label="ROC AUC")
    axes[0, 0].bar(x_positions + 0.18, accuracy_values, width=0.36, label="Accuracy")
    axes[0, 0].set_xticks(x_positions)
    axes[0, 0].set_xticklabels(model_names, rotation=20, ha="right")
    axes[0, 0].set_ylim(0.5, 0.65)
    axes[0, 0].set_title("Model metrics")
    axes[0, 0].legend()

    matrix = confusion_matrix(prepared.y_test, ensemble_labels)
    ConfusionMatrixDisplay(
        confusion_matrix=matrix,
        display_labels=["Bottom 15%", "Top 15%"],
    ).plot(ax=axes[0, 1], colorbar=False)
    axes[0, 1].set_title("Weighted ensemble confusion matrix")

    fpr, tpr, _ = roc_curve(prepared.y_test, ensemble_probabilities)
    axes[1, 0].plot(
        fpr,
        tpr,
        label=f"Weighted ensemble AUC = {metrics['weighted_ensemble']['roc_auc']:.4f}",
    )
    axes[1, 0].plot([0, 1], [0, 1], linestyle="--", color="gray")
    axes[1, 0].set_title("ROC curve")
    axes[1, 0].set_xlabel("False positive rate")
    axes[1, 0].set_ylabel("True positive rate")
    axes[1, 0].legend()

    top_features = list(reversed(feature_importance[:12]))
    axes[1, 1].barh(
        [feature for feature, _ in top_features],
        [importance for _, importance in top_features],
    )
    axes[1, 1].set_title("Top feature importance")
    axes[1, 1].set_xlabel("Weighted importance")

    fig.tight_layout()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_DIR / "best_model_report.png", dpi=160)
    plt.show()


def print_summary(
    metrics: dict[str, dict[str, float]],
    prepared: PreparedDataset,
    feature_importance: list[tuple[str, float]],
) -> None:
    print(f"Train rows: {len(prepared.train_rows)}")
    print(f"Test rows: {len(prepared.test_rows)}")
    print()

    for model_name, model_metrics in metrics.items():
        print(
            f"{model_name}: "
            f"accuracy={model_metrics['accuracy']:.6f}, "
            f"balanced_accuracy={model_metrics['balanced_accuracy']:.6f}, "
            f"roc_auc={model_metrics['roc_auc']:.6f}"
        )

    print()
    print("Top features:")
    for feature, importance in feature_importance[:10]:
        print(f"{feature}: {importance:.6f}")


def main() -> int:
    rows = load_rows(DATASET_PATH)
    add_quarter_rank_features(rows)
    labeled_rows = assign_tail_targets(rows, TARGET_TAIL_FRACTION)
    prepared = prepare_dataset(labeled_rows)
    metrics, probabilities, models = train_models(prepared)
    feature_importance = compute_weighted_feature_importance(models)

    save_outputs(metrics, probabilities, prepared, feature_importance)
    print_summary(metrics, prepared, feature_importance)
    plot_results(metrics, probabilities, prepared, feature_importance)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
