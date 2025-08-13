from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
from modules.image_tagger import tag_image


def test_tag_image_mock():
    tags = tag_image("sample.jpg")
    assert tags.get("trade") == "mock-trade"
