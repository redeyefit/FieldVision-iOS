from pathlib import Path
from typing import Dict, List
import csv


def load_schedule(path: Path) -> Dict[str, str]:
    schedule = {}
    with open(path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            schedule[row['trade']] = row['date']
    return schedule


def compare_progress(tagged: List[Dict], schedule: Dict[str, str]) -> List[str]:
    warnings = []
    for item in tagged:
        trade = item.get('trade')
        planned = schedule.get(trade)
        if not planned:
            continue
        warnings.append(f"{trade} expected {planned}, found in images")
    return warnings
