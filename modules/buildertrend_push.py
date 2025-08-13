from pathlib import Path
from typing import Optional

from config import BUILDERTREND_TOKEN


def push_report(report_path: Path) -> None:
    token = BUILDERTREND_TOKEN
    if token:
        # placeholder for API call
        print(f"[Buildertrend] Would upload {report_path}")
    else:
        print(f"Emailing {report_path} (not implemented)")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Push report")
    parser.add_argument("report")
    args = parser.parse_args()
    push_report(Path(args.report))
