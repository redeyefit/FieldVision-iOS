import os
from utils.logger import log
import config


def _sim_generate_frames(out_dir="frames", count=3):
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for i in range(1, count + 1):
        name = f"frame_00{i}.jpg"
        path = os.path.join(out_dir, name)
        # Lightweight placeholder to avoid numpy/pillow
        with open(path, "w") as f:
            f.write(f"[SIM FRAME PLACEHOLDER] {name}\n")
        log(f"Generated sim frame: {path}")
        paths.append(path)
    return paths


def slice_video(video_path: str, out_dir="frames", fps: int = 1, max_seconds: int = 60):
    """
    SIM: generates N placeholder frames (no deps).
    LIVE: uses OpenCV to slice frames. Guarded import & helpful errors.
    """
    if config.SIM_MODE or config.DEP_POLICY == "minimal":
        return _sim_generate_frames(out_dir)

    # LIVE path
    try:
        import cv2  # type: ignore
    except Exception as e:
        log(f"OpenCV unavailable ({e}); falling back to SIM frames.")
        return _sim_generate_frames(out_dir)

    os.makedirs(out_dir, exist_ok=True)
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        log(f"Could not open video: {video_path}; falling back to SIM frames.")
        return _sim_generate_frames(out_dir)

    frame_paths = []
    total = int(max_seconds * fps)
    frame_index = 0
    sec_step = 1.0 / max(fps, 1)

    # sample one frame per sec_step up to max_seconds
    for i in range(total):
        cap.set(cv2.CAP_PROP_POS_MSEC, i * 1000 * sec_step)
        ok, frame = cap.read()
        if not ok:
            break
        frame_index += 1
        out_name = f"frame_{frame_index:03d}.jpg"
        out_path = os.path.join(out_dir, out_name)
        cv2.imwrite(out_path, frame)
        frame_paths.append(out_path)
        log(f"Wrote frame: {out_path}")

    cap.release()
    if not frame_paths:
        log("No frames extracted; falling back to SIM frames.")
        return _sim_generate_frames(out_dir)
    return frame_paths
