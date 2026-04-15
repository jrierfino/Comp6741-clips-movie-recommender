import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


FACTS_PATH = Path("facts.clp")
OUTPUT_PATH = Path("tmdb_reviews.txt")
SEARCH_URL = "https://api.themoviedb.org/3/search/movie"
REVIEWS_URL = "https://api.themoviedb.org/3/movie/{movie_id}/reviews"


def read_movie_titles(facts_path: Path) -> list[str]:
    text = facts_path.read_text(encoding="utf-8", errors="ignore")
    titles = re.findall(r'\(movie \(title "([^"]+)"\)', text)
    return titles


def api_get(url: str, api_key: str, **params) -> dict:
    query = urllib.parse.urlencode({"api_key": api_key, **params})
    with urllib.request.urlopen(f"{url}?{query}") as response:
        return json.loads(response.read().decode("utf-8"))


def normalize_title(title: str) -> str:
    return re.sub(r"[^a-z0-9]", "", title.lower())


def choose_best_match(title: str, results: list[dict]) -> dict | None:
    if not results:
        return None

    target = normalize_title(title)

    for result in results:
        candidate = normalize_title(result.get("title", ""))
        if candidate == target:
            return result

    for result in results:
        candidate = normalize_title(result.get("title", ""))
        if target in candidate or candidate in target:
            return result

    return results[0]


def find_movie_id(title: str, api_key: str) -> tuple[int | None, str | None]:
    data = api_get(SEARCH_URL, api_key, query=title, include_adult="false", language="en-US", page=1)
    match = choose_best_match(title, data.get("results", []))
    if not match:
        return None, None
    return match.get("id"), match.get("title")


def fetch_reviews(movie_id: int, api_key: str, limit: int | None = None) -> list[dict]:
    reviews: list[dict] = []
    page = 1

    while True:
        data = api_get(
            REVIEWS_URL.format(movie_id=movie_id),
            api_key,
            language="en-US",
            page=page,
        )
        page_results = data.get("results", [])
        if not page_results:
            break

        reviews.extend(page_results)
        if limit is not None and len(reviews) >= limit:
            break

        total_pages = data.get("total_pages", 1)
        if page >= total_pages:
            break
        page += 1

    return reviews[:limit] if limit is not None else reviews


def trim_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    return text


def write_output(output_path: Path, rows: list[str]) -> None:
    output_path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch TMDb reviews for each movie in facts.clp.")
    parser.add_argument("--api-key", help="TMDb API key. If omitted, TMDB_API_KEY env var is used.")
    parser.add_argument("--facts", default=str(FACTS_PATH), help="Path to facts.clp")
    parser.add_argument("--output", default=str(OUTPUT_PATH), help="Output text file path")
    parser.add_argument("--max-reviews", type=int, default=None, help="Optional cap per movie. Default is all available reviews.")
    parser.add_argument("--sleep", type=float, default=0.1, help="Seconds to sleep between movies")
    args = parser.parse_args()

    api_key = args.api_key or os.environ.get("TMDB_API_KEY")
    if not api_key:
        print("Missing TMDb API key. Use --api-key or set TMDB_API_KEY.", file=sys.stderr)
        return 1

    facts_path = Path(args.facts)
    output_path = Path(args.output)
    titles = read_movie_titles(facts_path)

    rows: list[str] = []
    rows.append("TMDb Review Export")
    rows.append("=" * 80)
    rows.append(f"Movies found: {len(titles)}")
    rows.append("")

    for index, title in enumerate(titles, start=1):
        print(f"[{index}/{len(titles)}] Fetching reviews for: {title}")
        movie_id, matched_title = find_movie_id(title, api_key)

        rows.append("=" * 80)
        rows.append(f"Requested title: {title}")

        if movie_id is None:
            rows.append("TMDb match: NOT FOUND")
            rows.append("Reviews found: 0")
            rows.append("")
            continue

        rows.append(f"TMDb match: {matched_title} (ID: {movie_id})")
        reviews = fetch_reviews(movie_id, api_key, limit=args.max_reviews)
        rows.append(f"Reviews found: {len(reviews)}")
        rows.append("")

        if not reviews:
            rows.append("No reviews returned by TMDb.")
            rows.append("")
            time.sleep(args.sleep)
            continue

        for review_number, review in enumerate(reviews, start=1):
            author = review.get("author", "Unknown author")
            author_details = review.get("author_details", {}) or {}
            rating = author_details.get("rating")
            created = review.get("created_at", "Unknown date")
            content = trim_text(review.get("content", ""))

            rows.append(f"Review {review_number}")
            rows.append(f"Author: {author}")
            rows.append(f"Rating: {rating if rating is not None else 'N/A'}")
            rows.append(f"Created: {created}")
            rows.append("Content:")
            rows.append(content if content else "[No content]")
            rows.append("")

        time.sleep(args.sleep)

    write_output(output_path, rows)
    print(f"\nWrote reviews to: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
