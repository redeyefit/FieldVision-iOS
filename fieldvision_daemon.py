import asyncio
from pathlib import Path
from dotenv import load_dotenv
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from config import LOCAL_WATCH_PATH

from modules.video_frame_slicer import slice_video
from modules.frame_filter import filter_frames
from modules.image_tagger import tag_images
from modules.log_generator import generate_log
from modules.buildertrend_push import push_report
from utils.logging_utils import setup_logger
from utils.helpers import todays_log_dir

load_dotenv()
WATCH_PATH = Path(LOCAL_WATCH_PATH)
LOG_DIR = Path('logs')
logger = setup_logger('daemon', str(LOG_DIR / 'system.log'))


class MediaHandler(FileSystemEventHandler):
    def __init__(self):
        self.queue = asyncio.Queue()

    def on_created(self, event):
        if event.is_directory:
            return
        self.queue.put_nowait(Path(event.src_path))


async def process_media(handler: MediaHandler):
    processed_dates = set()
    while True:
        path = await handler.queue.get()
        date_folder = path.parent
        if date_folder in processed_dates:
            continue
        processed_dates.add(date_folder)
        try:
            await handle_folder(date_folder)
        except Exception as e:
            logger.error(f"Failed processing {date_folder}: {e}")


async def handle_folder(folder: Path):
    logger.info(f"Processing folder {folder}")
    frames = []
    for video in folder.glob('*.mp4'):
        frame_dir = folder / 'frames'
        frames.extend(slice_video(video, frame_dir))
    frames.extend(list(folder.glob('*.jpg')))
    filtered = filter_frames(frames)
    tags = tag_images(filtered)
    log_path = todays_log_dir(LOG_DIR)
    generate_log(tags, log_path)
    push_report(log_path / 'daily_log.pdf')
    logger.info(f"Finished {folder}")


def main():
    handler = MediaHandler()
    observer = Observer()
    observer.schedule(handler, str(WATCH_PATH), recursive=True)
    observer.start()
    logger.info(f"Watching {WATCH_PATH}")
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(process_media(handler))
    finally:
        observer.stop()
        observer.join()


if __name__ == '__main__':
    main()
