# Viet Deck

Transforms Annie's vietnamese 365 words into a flash card series.
https://www.youtube.com/watch?v=sE_Pp_2ESNQ&list=PLnVIHsBDulRMmZ6SCugqKyq6kv4QLAcWs

How to:

1. Download the video
2. Split scenes: `./split.sh video.mp4`
3. Manually remove useless slide (or change threshold+min slide length)
4. Extract Audio/Picture/Text: `./extract.sh video_dir`
5. Craft a CSV for Anki (using copilot): `./csv.sh video_dir`
6. Open Anki, impor the created CSV.
7. Copy the scene_audio+scene_picture files into the anki media dir (menu: `tools > check media > view files`)

Purification, Why?:
- solves vietnames character scanning issues not solved by tesseract OCR
- structured output (CSV) for the randomly positioned content
- (audio/picture) inclusion is a free gem, could be implemented straight forward if preferred

Dependencies:
- bash
- tesseract
- ffmpeg
- copilot (CLI)
