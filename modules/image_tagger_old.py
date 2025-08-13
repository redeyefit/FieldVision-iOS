# Legacy image tagger retained for reference; deprecated.
from pathlib import Path
from typing import Dict, List
import openai

from config import OPENAI_API_KEY


def tag_images(image_paths: List[Path]) -> List[Dict]:
    openai.api_key = OPENAI_API_KEY
    results = []
    for img in image_paths:
        # Placeholder call - replace with actual vision prompt
        # Here we simulate a tag response
        tag = {
            "file": str(img.name),
            "trade": "unknown",
            "completion": "0%",
            "notes": ""
        }
        results.append(tag)
    return results


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Tag images")
    parser.add_argument("images", nargs='+')
    args = parser.parse_args()
    tags = tag_images([Path(p) for p in args.images])
    for t in tags:
        print(t)
