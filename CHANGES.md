# Changelog

## Unreleased
- enhance `config.py` to auto-load `.env`, expose debug/performance flags, and provide helper `mode_summary`
- update modules to import configuration instead of using `os.getenv`
- include run_sim.sh and run_live.sh helpers
- expand `.env.example` with mode toggles
- commit placeholder `.env` and adjust setup instructions
- refactor `image_tagger` to use a mock implementation in `SIM_MODE` and stub live calls
- add simulation-first `video_frame_slicer` with optional OpenCV path; old implementation saved as `video_frame_slicer_old.py`
