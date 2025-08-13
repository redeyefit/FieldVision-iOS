from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
from config import mode_summary


def main():
    summary = mode_summary()
    required = ["SIM_MODE", "LIVE_MODE", "DEV_PROFILE", "DEP_POLICY", "LOCAL_WATCH_PATH"]
    for key in required:
        assert key in summary, f"{key} missing"
    print("config summary OK")


if __name__ == "__main__":
    main()
