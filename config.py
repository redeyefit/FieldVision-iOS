"""FieldVision Config Loader
-------------------------
Centralizes environment variable loading so that:
1. Local `.env` files are respected during development.
2. Codex IDE Environment Variables are used automatically in cloud runs.
3. Simulation/Live mode flags are consistent across environments.
"""

import os
from pathlib import Path

try:
    from dotenv import load_dotenv
except Exception:  # pragma: no cover - fallback if python-dotenv missing
    def load_dotenv(*args, **kwargs):  # type: ignore
        return False

# 1. Try to load local .env if it exists
dotenv_path = Path(__file__).parent / ".env"
if dotenv_path.exists():
    load_dotenv(dotenv_path)


# 2. Helper: Get env with optional default
def get_env(name: str, default: str = None) -> str:
    return os.getenv(name, default)


# 3. Core config values
DRIVE_FOLDER_ID = get_env("DRIVE_FOLDER_ID")
SERVICE_ACCOUNT_JSON = get_env("SERVICE_ACCOUNT_JSON")
OPENAI_API_KEY = get_env("OPENAI_API_KEY")
BUILDERTREND_TOKEN = get_env("BUILDERTREND_TOKEN", "")

LOCAL_WATCH_PATH = get_env("LOCAL_WATCH_PATH", "./FieldVision")


# 4. Mode flags
SIM_MODE = get_env("SIM_MODE", "true").lower() == "true"
LIVE_MODE = get_env("LIVE_MODE", "false").lower() == "true"
DEV_PROFILE = get_env("DEV_PROFILE", "simulation-heavy")
DEP_POLICY = get_env("DEP_POLICY", "minimal")


# 5. Optional debug + performance
DEBUG_MODE = get_env("DEBUG_MODE", "false").lower() == "true"
LOG_LEVEL = get_env("LOG_LEVEL", "info")
TEST_DATA_PATH = get_env("TEST_DATA_PATH", "./tests/data")
SRC_PATH = get_env("SRC_PATH", "./src")
PIPELINE_PATH = get_env("PIPELINE_PATH", "./pipeline")
MAX_FRAMES = int(get_env("MAX_FRAMES", "50"))
TIMEOUT_SECONDS = int(get_env("TIMEOUT_SECONDS", "60"))


def mode_summary():
    """Returns a quick-read summary of current mode and policy settings."""
    return {
        "SIM_MODE": SIM_MODE,
        "LIVE_MODE": LIVE_MODE,
        "DEV_PROFILE": DEV_PROFILE,
        "DEP_POLICY": DEP_POLICY,
        "LOCAL_WATCH_PATH": LOCAL_WATCH_PATH,
        "MAX_FRAMES": MAX_FRAMES,
        "TIMEOUT_SECONDS": TIMEOUT_SECONDS,
    }


# 6. Startup log (optional for visibility)
if DEBUG_MODE:
    print("[CONFIG] Loaded configuration:")
    for key in [
        "SIM_MODE",
        "LIVE_MODE",
        "DEV_PROFILE",
        "DEP_POLICY",
        "LOCAL_WATCH_PATH",
        "MAX_FRAMES",
        "TIMEOUT_SECONDS",
    ]:
        print(f"  {key} = {globals()[key]}")


if __name__ == "__main__":
    from pprint import pprint

    print("FieldVision Configuration:")
    pprint(mode_summary())

