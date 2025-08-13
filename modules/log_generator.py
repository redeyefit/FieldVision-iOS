from pathlib import Path
from datetime import datetime
from typing import List, Dict
import pdfkit
from jinja2 import Template

TEMPLATE = Template(
"""# Daily Log - {{ date }}\n\n{% for item in items %}- **{{item.file}}** | {{item.trade}} | {{item.completion}}\n{% endfor %}"""
)


def generate_markdown(tagged: List[Dict], output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    md_path = output_dir / 'daily_log.md'
    content = TEMPLATE.render(date=datetime.now().date(), items=tagged)
    md_path.write_text(content)
    return md_path


def generate_pdf(markdown_path: Path) -> Path:
    pdf_path = markdown_path.with_suffix('.pdf')
    try:
        pdfkit.from_file(str(markdown_path), str(pdf_path))
    except Exception:
        pass
    return pdf_path


def generate_log(tagged: List[Dict], output_dir: Path) -> None:
    md = generate_markdown(tagged, output_dir)
    generate_pdf(md)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Generate log")
    parser.add_argument("tag_json", nargs='+')
    args = parser.parse_args()
    import json
    tagged = []
    for f in args.tag_json:
        tagged.extend(json.load(open(f)))
    generate_log(tagged, Path('./logs'))
