# FieldVision

This repository contains both the initial iOS scaffold and the Python-based FieldVision daemon. The daemon watches a Google Drive folder (or local directory during development), processes new videos and images, and generates a daily report summarizing jobsite progress.

## Setup

1. Install Python 3.10+
2. Create a virtual environment and install dependencies:
   ```bash
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. Edit the included `.env` file with your API keys and paths. A `.env.example` is also provided as a reference template. `config.py` uses `python-dotenv` to auto-load this file and falls back to environment variables in cloud runs. Mode toggles like `SIM_MODE` and `LIVE_MODE` plus optional debug flags such as `DEBUG_MODE` can be adjusted here.
4. (Optional) Run `./prep_repo.sh` to format code and confirm folder setup.

## Running the Daemon

To run in simulation or live mode, use the provided helper scripts:

```
./run_sim.sh  # simulation mode
./run_live.sh # live mode
```

Both scripts export the relevant environment toggles and then launch the daemon. The daemon will continuously watch the configured folder for new media and produce a Markdown and PDF log under `logs/YYYY-MM-DD/`.

## Module Overview

- `fieldvision_daemon.py` – orchestrates the workflow and monitors the drive folder
- `modules/video_frame_slicer.py` – extracts frames from videos (SIM: placeholder frames; LIVE: requires OpenCV)
- `modules/frame_filter.py` – removes blurry or duplicate images
- `modules/image_tagger.py` – tags images via a mock or GPT-4 Vision based on mode
- `modules/log_generator.py` – compiles a Markdown and PDF report
- `modules/buildertrend_push.py` – optional integration for sending reports
- `modules/schedule_comparator.py` – compare tagged progress to a baseline schedule

Each module can also be executed standalone for testing.

