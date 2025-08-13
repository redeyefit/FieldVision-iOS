from pathlib import Path
import sys
import tempfile

sys.path.append(str(Path(__file__).resolve().parents[1]))
from modules.video_frame_slicer import slice_video


def main():
    with tempfile.TemporaryDirectory() as tmpdir:
        paths = slice_video("dummy.mp4", out_dir=tmpdir)
        assert len(paths) == 3
        for p in paths:
            assert Path(p).exists()
            assert "[SIM FRAME PLACEHOLDER]" in Path(p).read_text()
    print("video_frame_slicer sim test OK")


if __name__ == "__main__":
    main()
