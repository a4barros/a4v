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

# Copy index.html
cp assets/template.html $OUTPUT_DIR/index.html
sed -i "s/{{ video_name }}/$BASENAME/g" $OUTPUT_DIR/index.html

echo "Output directory: $OUTPUT_DIR"
