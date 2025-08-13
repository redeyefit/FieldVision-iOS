from datetime import datetime
from pathlib import Path


def todays_log_dir(base_dir: Path) -> Path:
    today = datetime.now().strftime("%Y-%m-%d")
    log_dir = base_dir / today
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir
