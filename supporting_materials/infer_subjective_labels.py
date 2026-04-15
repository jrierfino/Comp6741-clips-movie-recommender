import argparse
import math
import re
from collections import defaultdict
from pathlib import Path


INPUT_PATH = Path("tmdb_reviews.txt")
OUTPUT_PATH = Path("subjective_inference.txt")

FEATURES = {
    "scariness": {
        "labels": ["none", "mild", "high"],
        "keywords": {
            "high": [
                "terrifying", "horrifying", "nightmare", "scary as hell", "very scary",
                "genuinely scary", "intense horror", "frightening", "disturbing", "creepy",
                "haunting", "scary", "horror", "fear", "dread", "panic", "chilling",
            ],
            "mild": [
                "slightly scary", "a little scary", "mildly scary", "tense", "suspenseful",
                "uneasy", "eerie", "spooky", "creepy at times", "thrilling",
            ],
            "none": [
                "not scary", "isn't scary", "never scary", "not frightening", "no scares",
                "not horror", "family friendly", "lighthearted", "fun adventure",
            ],
        },
    },
    "violence": {
        "labels": ["low", "medium", "high"],
        "keywords": {
            "high": [
                "brutal", "graphic", "gory", "bloody", "ultraviolent", "very violent",
                "intense violence", "violent", "body count", "gruesome", "savage",
            ],
            "medium": [
                "action violence", "some violence", "moderate violence", "fight scenes",
                "combat", "gunplay", "dark", "tense action", "rough",
            ],
            "low": [
                "nonviolent", "not violent", "little violence", "gentle", "family film",
                "wholesome", "soft", "light", "warm",
            ],
        },
    },
    "complexity": {
        "labels": ["easy", "medium", "complex"],
        "keywords": {
            "complex": [
                "confusing", "complex", "complicated", "layered", "dense", "challenging",
                "mind-bending", "mind bending", "thought-provoking", "puzzling", "intricate",
                "ambiguous", "deep", "philosophical",
            ],
            "medium": [
                "smart", "clever", "balanced", "engaging", "interesting", "well structured",
                "a bit confusing", "moderately complex",
            ],
            "easy": [
                "simple", "straightforward", "easy to follow", "accessible", "predictable",
                "basic", "clear", "light entertainment",
            ],
        },
    },
    "mood": {
        "labels": ["light", "intense", "emotional", "mindbending", "scary"],
        "keywords": {
            "light": [
                "fun", "funny", "light", "lighthearted", "charming", "playful", "sweet",
                "feel-good", "uplifting", "heartwarming", "warm", "cheerful",
            ],
            "intense": [
                "intense", "thrilling", "tense", "pulse-pounding", "gripping", "adrenaline",
                "relentless", "edge of your seat", "suspenseful", "raw",
            ],
            "emotional": [
                "emotional", "touching", "moving", "heartbreaking", "tearjerker", "sad",
                "beautiful", "bittersweet", "sentimental", "poignant",
            ],
            "mindbending": [
                "mind-bending", "mind bending", "trippy", "surreal", "thought-provoking",
                "twisty", "cerebral", "heady", "puzzling", "brainy",
            ],
            "scary": [
                "scary", "frightening", "creepy", "horrifying", "disturbing", "terrifying",
                "dread", "nightmarish",
            ],
        },
    },
}


def parse_reviews(path: Path) -> dict[str, list[str]]:
    reviews_by_movie: dict[str, list[str]] = defaultdict(list)
    current_title = None
    collecting = False
    buffer: list[str] = []

    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.rstrip()

        if line.startswith("Requested title: "):
            current_title = line.split(": ", 1)[1].strip()
            continue

        if line == "Content:":
            collecting = True
            buffer = []
            continue

        if collecting and line.startswith("Review "):
            if current_title is not None and buffer:
                reviews_by_movie[current_title].append(" ".join(buffer).strip())
            buffer = []
            collecting = False

        if collecting:
            if line == "":
                if current_title is not None and buffer:
                    reviews_by_movie[current_title].append(" ".join(buffer).strip())
                buffer = []
                collecting = False
            else:
                buffer.append(line)

    if collecting and current_title is not None and buffer:
        reviews_by_movie[current_title].append(" ".join(buffer).strip())

    return reviews_by_movie


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower())


def count_keyword_hits(text: str, phrases: list[str]) -> int:
    hits = 0
    for phrase in phrases:
        hits += len(re.findall(re.escape(phrase.lower()), text))
    return hits


def infer_feature(feature_name: str, reviews: list[str]) -> dict:
    feature = FEATURES[feature_name]
    labels = feature["labels"]
    label_scores: dict[str, float] = {label: 0.0 for label in labels}

    for review in reviews:
        norm = normalize_text(review)
        for label in labels:
            hits = count_keyword_hits(norm, feature["keywords"][label])
            if hits:
                label_scores[label] += hits

    total_signal = sum(label_scores.values())

    if total_signal == 0:
        crisp = labels[0]
        fuzzy = {label: (1.0 if label == crisp else 0.0) for label in labels}
        return {
            "crisp": crisp,
            "cf_label": crisp,
            "cf_value": 0.0,
            "fuzzy": fuzzy,
            "scores": label_scores,
            "signal": 0.0,
        }

    sorted_labels = sorted(labels, key=lambda label: label_scores[label], reverse=True)
    top_label = sorted_labels[0]
    second_score = label_scores[sorted_labels[1]] if len(sorted_labels) > 1 else 0.0
    top_score = label_scores[top_label]

    margin = max(top_score - second_score, 0.0)
    signal_strength = min(total_signal / max(len(reviews), 1), 3.0) / 3.0
    margin_strength = margin / top_score if top_score > 0 else 0.0
    cf_value = round(min(0.95, 0.2 + 0.5 * signal_strength + 0.25 * margin_strength), 2)

    fuzzy = {
        label: round(label_scores[label] / top_score, 2) if top_score > 0 else 0.0
        for label in labels
    }
    fuzzy[top_label] = 1.0

    return {
        "crisp": top_label,
        "cf_label": top_label,
        "cf_value": cf_value,
        "fuzzy": fuzzy,
        "scores": label_scores,
        "signal": round(total_signal, 2),
    }


def render_movie_block(title: str, reviews: list[str], inferred: dict[str, dict]) -> list[str]:
    lines = []
    lines.append("=" * 80)
    lines.append(f"Movie: {title}")
    lines.append(f"Reviews analyzed: {len(reviews)}")
    lines.append("")

    for feature_name in ["mood", "scariness", "violence", "complexity"]:
        result = inferred[feature_name]
        lines.append(f"{feature_name.upper()}")
        lines.append(f"  Crisp label: {result['crisp']}")
        lines.append(f"  CF label/value: {result['cf_label']} / {result['cf_value']}")
        fuzzy_parts = ", ".join(
            f"{label}={result['fuzzy'][label]}"
            for label in FEATURES[feature_name]["labels"]
        )
        lines.append(f"  Fuzzy values: {fuzzy_parts}")
        score_parts = ", ".join(
            f"{label}={int(result['scores'][label]) if float(result['scores'][label]).is_integer() else round(result['scores'][label], 2)}"
            for label in FEATURES[feature_name]["labels"]
        )
        lines.append(f"  Raw evidence scores: {score_parts}")
        lines.append(f"  Total signal: {result['signal']}")
        lines.append("")

    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description="Infer subjective labels, CF values, and fuzzy values from TMDb reviews.")
    parser.add_argument("--input", default=str(INPUT_PATH), help="Path to tmdb_reviews.txt")
    parser.add_argument("--output", default=str(OUTPUT_PATH), help="Path to output text file")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    reviews_by_movie = parse_reviews(input_path)

    lines = []
    lines.append("Subjective Attribute Inference")
    lines.append("=" * 80)
    lines.append("Method: keyword-based evidence extraction from TMDb reviews")
    lines.append("Features analyzed: mood, scariness, violence, complexity")
    lines.append("")

    for title in sorted(reviews_by_movie):
        reviews = reviews_by_movie[title]
        inferred = {
            feature_name: infer_feature(feature_name, reviews)
            for feature_name in FEATURES
        }
        lines.extend(render_movie_block(title, reviews, inferred))

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote inference report to: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
