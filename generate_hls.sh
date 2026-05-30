#!/bin/bash
# Usage: ./generate_hls.sh input.mp4

set -e

INPUT="$1"

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <input_video>"
  exit 1
fi

# Base name without extension
BASENAME=$(basename "$INPUT" | cut -d. -f1)

# Output folder
OUTPUT_DIR="public/$BASENAME"
mkdir -p "$OUTPUT_DIR"

# Define renditions (resolution and bitrate)
# Format: "<height>:<video_bitrate>:<audio_bitrate>"
RENDITIONS=(
  "240:400k:64k"
  "480:800k:96k"
  "720:2000k:128k"
  "1080:5000k:192k"
)

read -p "Enter a title for the video: " TITLE
sed -i "s/{{ video_name }}/$TITLE/g" $OUTPUT_DIR/index.html

read -p "Enter a description for the video: " DESCRIPTION
sed -i "s/{{ video_description }}/$DESCRIPTION/g" $OUTPUT_DIR/index.html

read -p "Do you want to encode a 4K version? (y/n) " ENCODE_4K
if [[ "$ENCODE_4K" == "y" ]]; then
  RENDITIONS+=("2160:15000k:320k")
fi

# Create variant playlists
for REND in "${RENDITIONS[@]}"; do
  HEIGHT=$(echo "$REND" | cut -d: -f1)
  VB=$(echo "$REND" | cut -d: -f2)
  AB=$(echo "$REND" | cut -d: -f3)

  echo "➡️  Processing ${HEIGHT}p (${VB} video / ${AB} audio)"

  ffmpeg -y -i "$INPUT" \
    -vf "scale=-2:${HEIGHT}" \
    -c:a aac -ar 48000 -b:a $AB \
    -c:v h264 -profile:v main -crf 20 -g 48 -keyint_min 48 \
    -b:v $VB -maxrate $VB -bufsize $(echo $VB | sed 's/k$/k/') \
    -hls_time 6 -hls_playlist_type vod \
    -hls_segment_filename "${OUTPUT_DIR}/${HEIGHT}p_%03d.ts" \
    "${OUTPUT_DIR}/${HEIGHT}p.m3u8"
done

# Create master playlist
MASTER_PLAYLIST="${OUTPUT_DIR}/master.m3u8"
echo "#EXTM3U" > "$MASTER_PLAYLIST"

for REND in "${RENDITIONS[@]}"; do
  HEIGHT=$(echo "$REND" | cut -d: -f1)
  VB=$(echo "$REND" | cut -d: -f2)
  echo "#EXT-X-STREAM-INF:BANDWIDTH=${VB//k/000},RESOLUTION=1280x${HEIGHT}" >> "$MASTER_PLAYLIST"
  echo "${HEIGHT}p.m3u8" >> "$MASTER_PLAYLIST"
done

# Get video duration in seconds
DURATION=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$INPUT")

# Copy assets
cp assets/* $OUTPUT_DIR/

# Generate random timestamp
RAND_TIME=$(awk -v dur="$DURATION" 'BEGIN{srand(); print rand()*dur}')

echo "🖼 Generating thumbnail at ${RAND_TIME}s"

ffmpeg -y -ss "$RAND_TIME" -i "$INPUT" \
  -frames:v 1 \
  -q:v 2 \
  "${OUTPUT_DIR}/thumbnail.jpg"

ffmpeg -y -ss "$RAND_TIME" -i "$INPUT" \
  -frames:v 1 \
  -q:v 2 \
  -vf "scale=1200:630:force_original_aspect_ratio=decrease,pad=1200:630:(ow-iw)/2:(oh-ih)/2" \
  "${OUTPUT_DIR}/thumbnail_for_og.jpg"

echo "Output directory: $OUTPUT_DIR"
