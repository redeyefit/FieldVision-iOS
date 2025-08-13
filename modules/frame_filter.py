from pathlib import Path
import cv2
import hashlib
from typing import List


def is_blurry(image_path: Path, threshold: float = 100.0) -> bool:
    img = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
    if img is None:
        return True
    variance = cv2.Laplacian(img, cv2.CV_64F).var()
    return variance < threshold


def filter_frames(frame_paths: List[Path]) -> List[Path]:
    hashes = set()
    kept = []
    for p in frame_paths:
        if is_blurry(p):
            continue
        with open(p, 'rb') as f:
            file_hash = hashlib.md5(f.read()).hexdigest()
        if file_hash in hashes:
            continue
        hashes.add(file_hash)
        kept.append(p)
    return kept


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Filter frames")
    parser.add_argument("frames", nargs='+')
    args = parser.parse_args()
    kept = filter_frames([Path(p) for p in args.frames])
    print(f"Kept {len(kept)} / {len(args.frames)} frames")
