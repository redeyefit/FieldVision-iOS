import os
import config
from utils.logger import log


def tag_image(img_path: str) -> dict:
    """
    Returns tags for a given image path.
    SIM: uses mock_vision
    LIVE: calls GPT Vision (placeholder here, guarded by OPENAI_API_KEY)
    """
    if config.SIM_MODE or config.DEV_PROFILE == "simulation-heavy":
        from mock_vision import mock_vision_output  # local mock
        name = os.path.basename(img_path)
        tags = mock_vision_output(name) or {}
        if not tags:
            log(f"No tags for {name} (mock).")
        return tags

    # LIVE path (kept slim; you’ll flesh out the API call later)
    api_key = config.OPENAI_API_KEY
    if not api_key:
        log("OPENAI_API_KEY missing; falling back to mock tags.")
        from mock_vision import mock_vision_output
        return mock_vision_output(os.path.basename(img_path)) or {}

    # TODO: implement real vision call
    # Example outline (leave unimplemented to avoid failures in Codex IDE):
    # tags = call_gpt_vision_api(img_path, api_key)
    # return tags
    log("LIVE_MODE true but live tagger not implemented; returning empty tags.")
    return {}
