from pathlib import Path
import cv2


def slice_video(video_path: Path, output_dir: Path, fps: int = 1, max_duration: int = 60) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise ValueError(f"Cannot open video {video_path}")

    frame_paths = []
    frame_count = 0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    video_fps = cap.get(cv2.CAP_PROP_FPS) or 30
    interval = int(video_fps / fps)
    max_frames = min(total_frames, max_duration * fps)

    while cap.isOpened() and frame_count < max_frames:
        ret, frame = cap.read()
        if not ret:
            break
        if int(cap.get(cv2.CAP_PROP_POS_FRAMES)) % interval == 0:
            frame_file = output_dir / f"{video_path.stem}_frame{frame_count:03d}.jpg"
            cv2.imwrite(str(frame_file), frame)
            frame_paths.append(frame_file)
            frame_count += 1
    cap.release()
    return frame_paths


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Slice video into frames")
    parser.add_argument("video")
    parser.add_argument("output_dir")
    args = parser.parse_args()
    paths = slice_video(Path(args.video), Path(args.output_dir))
    print(f"Saved {len(paths)} frames")
