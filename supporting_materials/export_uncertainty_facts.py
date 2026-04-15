import argparse
import re
from pathlib import Path


INPUT_PATH = Path("subjective_inference.txt")
OUTPUT_PATH = Path("candidate_uncertainty_facts.txt")


def parse_inference(path: Path) -> dict[str, dict[str, dict]]:
    movies: dict[str, dict[str, dict]] = {}
    current_movie = None
    current_feature = None

    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()

    for raw_line in lines:
        line = raw_line.rstrip()

        if line.startswith("Movie: "):
            current_movie = line.split(": ", 1)[1].strip()
            movies[current_movie] = {}
            current_feature = None
            continue

        if line in {"MOOD", "SCARINESS", "VIOLENCE", "COMPLEXITY"}:
            current_feature = line.lower()
            movies[current_movie][current_feature] = {}
            continue

        if current_movie is None or current_feature is None:
            continue

        if line.strip().startswith("Crisp label: "):
            movies[current_movie][current_feature]["crisp"] = line.split(": ", 1)[1].strip()
        elif line.strip().startswith("CF label/value: "):
            payload = line.split(": ", 1)[1].strip()
            label, value = [part.strip() for part in payload.split("/", 1)]
            movies[current_movie][current_feature]["cf_label"] = label
            movies[current_movie][current_feature]["cf_value"] = float(value)
        elif line.strip().startswith("Fuzzy values: "):
            payload = line.split(": ", 1)[1].strip()
            fuzzy = {}
            for pair in payload.split(", "):
                label, value = pair.split("=")
                fuzzy[label.strip()] = float(value.strip())
            movies[current_movie][current_feature]["fuzzy"] = fuzzy

    return movies


def build_cf_facts(data: dict[str, dict[str, dict]], cf_threshold: float) -> list[str]:
    facts = []
    for movie, features in sorted(data.items()):
        for feature, info in features.items():
            cf_value = info.get("cf_value", 0.0)
            if cf_value >= cf_threshold:
                label = info.get("cf_label", info.get("crisp"))
                facts.append(
                    f'(prob-evidence (title "{movie}") (feature {feature}) (value {label}) '
                    f'(cf {cf_value:.2f}) (source "TMDb review inference"))'
                )
    return facts


def build_fuzzy_facts(
    data: dict[str, dict[str, dict]],
    fuzzy_threshold: float,
    max_labels: int,
) -> list[str]:
    facts = []
    for movie, features in sorted(data.items()):
        candidate_feature_blocks = []
        for feature, info in features.items():
            fuzzy = info.get("fuzzy", {})
            if not fuzzy:
                continue

            ranked = sorted(fuzzy.items(), key=lambda item: item[1], reverse=True)
            if not ranked:
                continue

            top_mu = ranked[0][1]
            top_count = sum(1 for _, mu in ranked if mu == top_mu)

            if top_count > 1:
                continue

            kept = []
            for label, mu in ranked:
                if len(kept) == 0:
                    kept.append((label, mu))
                    continue

                if any(existing_mu == mu for _, existing_mu in kept):
                    continue

                if mu >= fuzzy_threshold and len(kept) < max_labels:
                    kept.append((label, mu))

            if len(kept) < 2:
                continue

            secondary_strength = kept[1][1]
            candidate_feature_blocks.append((secondary_strength, feature, kept))

        if not candidate_feature_blocks:
            continue

        candidate_feature_blocks.sort(key=lambda item: item[0], reverse=True)
        _, chosen_feature, chosen_labels = candidate_feature_blocks[0]

        for label, mu in chosen_labels:
            facts.append(
                f'(fuzzy-degree (title "{movie}") (feature {chosen_feature}) (label {label}) '
                f'(mu {mu:.2f}) (source "TMDb review inference"))'
            )
    return facts


def main() -> int:
    parser = argparse.ArgumentParser(description="Export candidate CF and fuzzy facts from subjective_inference.txt")
    parser.add_argument("--input", default=str(INPUT_PATH), help="Path to subjective_inference.txt")
    parser.add_argument("--output", default=str(OUTPUT_PATH), help="Output text file path")
    parser.add_argument("--cf-threshold", type=float, default=0.55, help="Minimum CF value to export")
    parser.add_argument("--fuzzy-threshold", type=float, default=0.30, help="Minimum secondary fuzzy membership to export")
    parser.add_argument("--max-fuzzy-labels", type=int, default=2, help="Maximum fuzzy labels to export per movie-feature")
    args = parser.parse_args()

    data = parse_inference(Path(args.input))
    cf_facts = build_cf_facts(data, args.cf_threshold)
    fuzzy_facts = build_fuzzy_facts(data, args.fuzzy_threshold, args.max_fuzzy_labels)

    lines = []
    lines.append("Candidate Uncertainty Facts")
    lines.append("=" * 80)
    lines.append(f"CF threshold: {args.cf_threshold}")
    lines.append(f"Fuzzy threshold: {args.fuzzy_threshold}")
    lines.append(f"Max fuzzy labels per feature: {args.max_fuzzy_labels}")
    lines.append("")
    lines.append("; ---------- Candidate CF facts ----------")
    lines.extend(cf_facts or ["; None"])
    lines.append("")
    lines.append("; ---------- Candidate fuzzy facts ----------")
    lines.extend(fuzzy_facts or ["; None"])
    lines.append("")
    lines.append(f"CF facts generated: {len(cf_facts)}")
    lines.append(f"Fuzzy facts generated: {len(fuzzy_facts)}")

    Path(args.output).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote candidate facts to: {args.output}")
    print(f"CF facts generated: {len(cf_facts)}")
    print(f"Fuzzy facts generated: {len(fuzzy_facts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
