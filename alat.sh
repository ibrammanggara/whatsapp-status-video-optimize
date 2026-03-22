#!/bin/bash

# ╔══════════════════════════════════════════════╗
# ║         WA Video Compressor v1.0             ║
# ║     Optimized for WhatsApp Business Status   ║
# ╚══════════════════════════════════════════════╝

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
BG_GREEN='\033[42m'
BG_DARK='\033[40m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORTED_FORMATS=("mp4" "mov" "avi" "mkv" "webm" "flv" "wmv" "m4v" "3gp" "ts")

# ── Banner ──────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║  📱  WA Video Compressor  v1.0  📱   ║"
  echo "  ║   Optimized for WhatsApp Status       ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ── Spinner frames ───────────────────────────────
SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# ── List available video files ───────────────────
list_videos() {
  local found=()
  for ext in "${SUPPORTED_FORMATS[@]}"; do
    while IFS= read -r -d '' f; do
      found+=("$(basename "$f")")
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -iname "*.$ext" -print0 2>/dev/null)
  done

  if [ ${#found[@]} -eq 0 ]; then
    echo -e "${RED}  ✗ Tidak ada file video ditemukan di folder ini.${RESET}"
    echo -e "${DIM}  Supported: ${SUPPORTED_FORMATS[*]}${RESET}"
    echo ""
    exit 1
  fi

  echo -e "${YELLOW}${BOLD}  📂 Video tersedia:${RESET}"
  for i in "${!found[@]}"; do
    echo -e "     ${CYAN}[$((i+1))]${RESET} ${found[$i]}"
  done
  echo ""
  echo "${found[@]}"
}

# ── Get video duration in seconds ────────────────
get_duration() {
  ffprobe -v quiet -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

# ── Progress bar renderer ─────────────────────────
render_progress() {
  local percent=$1
  local elapsed=$2
  local eta=$3
  local bar_width=36
  local filled=$(( percent * bar_width / 100 ))
  local empty=$(( bar_width - filled ))

  local bar="${GREEN}"
  for ((i=0; i<filled; i++)); do bar+="█"; done
  bar+="${DIM}"
  for ((i=0; i<empty; i++)); do bar+="░"; done
  bar+="${RESET}"

  local eta_str=""
  if [ "$eta" -gt 0 ] 2>/dev/null; then
    local eta_min=$(( eta / 60 ))
    local eta_sec=$(( eta % 60 ))
    eta_str=$(printf "ETA %02d:%02d" $eta_min $eta_sec)
  else
    eta_str="menghitung..."
  fi

  printf "\r  ${bar} ${BOLD}${YELLOW}%3d%%${RESET}  ${DIM}%s${RESET}  ⏱ ${DIM}%s${RESET}" \
    "$percent" "$eta_str" "$(printf '%02d:%02d' $((elapsed/60)) $((elapsed%60)))"
}

# ── Compress function ─────────────────────────────
compress_video() {
  local input="$1"
  local filename="${input%.*}"
  local output="${filename}_wa.mp4"
  local duration
  duration=$(get_duration "$input")

  if [ -z "$duration" ] || [ "$duration" = "N/A" ]; then
    echo -e "${RED}  ✗ Gagal membaca durasi video.${RESET}"
    exit 1
  fi

  local dur_int=${duration%.*}

  echo ""
  echo -e "${MAGENTA}${BOLD}  🎬 Input   :${RESET} $input"
  echo -e "${MAGENTA}${BOLD}  💾 Output  :${RESET} $output"
  echo -e "${MAGENTA}${BOLD}  ⏱ Durasi  :${RESET} $(printf '%02d:%02d' $((dur_int/60)) $((dur_int%60)))"
  echo ""
  echo -e "${CYAN}  ⚙️  Memulai kompresi...${RESET}"
  echo ""

  local progress_file
  progress_file=$(mktemp)
  local start_time=$SECONDS

  # Run ffmpeg in background, pipe stderr to progress file
  ffmpeg -y -i "$input" \
    -vf "scale='if(gt(iw,ih),1920,1080)':'if(gt(iw,ih),1080,1920)'" \
    -c:v libx264 -crf 18 -preset slow \
    -tune film -r 60 \
    -c:a aac -b:a 128k -movflags +faststart \
    "$output" 2>"$progress_file" &

  local ffmpeg_pid=$!
  local spin_idx=0

  while kill -0 $ffmpeg_pid 2>/dev/null; do
    local elapsed=$(( SECONDS - start_time ))
    local current_time=0
    local percent=0
    local eta=0

    # Parse current time from ffmpeg output
    local last_line
    last_line=$(grep "time=" "$progress_file" 2>/dev/null | tail -1)

    if [ -n "$last_line" ]; then
      local time_str
      time_str=$(echo "$last_line" | grep -oP 'time=\K[0-9:]+' | tail -1)
      if [ -n "$time_str" ]; then
        local h m s
        IFS=: read -r h m s <<< "$time_str"
        s=${s%.*}
        current_time=$(( 10#$h * 3600 + 10#$m * 60 + 10#${s:-0} ))
        if [ "$dur_int" -gt 0 ]; then
          percent=$(( current_time * 100 / dur_int ))
          [ "$percent" -gt 100 ] && percent=100
          if [ "$elapsed" -gt 0 ] && [ "$percent" -gt 0 ]; then
            local total_est=$(( elapsed * 100 / percent ))
            eta=$(( total_est - elapsed ))
            [ "$eta" -lt 0 ] && eta=0
          fi
        fi
      fi
    fi

    local spin="${SPINNER[$spin_idx]}"
    spin_idx=$(( (spin_idx + 1) % ${#SPINNER[@]} ))

    printf "\r  ${CYAN}${spin}${RESET} "
    render_progress "$percent" "$elapsed" "$eta"

    sleep 0.2
  done

  wait $ffmpeg_pid
  local exit_code=$?
  rm -f "$progress_file"

  echo ""
  echo ""

  if [ $exit_code -eq 0 ]; then
    local final_size
    final_size=$(du -sh "$output" 2>/dev/null | cut -f1)
    local elapsed=$(( SECONDS - start_time ))

    echo -e "${GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║   ✅  Kompresi Selesai!               ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREEN}📦 Output  :${RESET} ${BOLD}$output${RESET}"
    echo -e "  ${GREEN}📏 Ukuran  :${RESET} $final_size"
    echo -e "  ${GREEN}⏱ Waktu   :${RESET} $(printf '%02d:%02d' $((elapsed/60)) $((elapsed%60)))"
    echo -e "  ${GREEN}🚀 Siap upload ke WhatsApp Status!${RESET}"
    echo ""
  else
    echo -e "${RED}${BOLD}  ✗ Kompresi gagal. Cek file input atau ffmpeg.${RESET}"
    echo ""
    exit 1
  fi
}

# ── Main ──────────────────────────────────────────
main() {
  print_banner

  # Check ffmpeg
  if ! command -v ffmpeg &>/dev/null; then
    echo -e "${RED}  ✗ ffmpeg tidak ditemukan. Install dulu: sudo apt install ffmpeg${RESET}"
    exit 1
  fi

  # List videos
  echo -e "${DIM}  Folder: $SCRIPT_DIR${RESET}"
  echo ""

  local video_list=()
  for ext in "${SUPPORTED_FORMATS[@]}"; do
    while IFS= read -r -d '' f; do
      video_list+=("$(basename "$f")")
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -iname "*.$ext" -print0 2>/dev/null)
  done

  if [ ${#video_list[@]} -eq 0 ]; then
    echo -e "${RED}  ✗ Tidak ada file video ditemukan di folder ini.${RESET}"
    echo -e "${DIM}  Supported: ${SUPPORTED_FORMATS[*]}${RESET}"
    echo ""
    exit 1
  fi

  echo -e "${YELLOW}${BOLD}  📂 Video tersedia:${RESET}"
  for i in "${!video_list[@]}"; do
    echo -e "     ${CYAN}[$((i+1))]${RESET} ${video_list[$i]}"
  done
  echo ""

  # Input nama file
  echo -e -n "  ${BOLD}Masukkan nama file (tanpa ekstensi) atau nomor: ${RESET}"
  read -r user_input

  local target_file=""

  # Cek apakah input angka (pilih dari list)
  if [[ "$user_input" =~ ^[0-9]+$ ]]; then
    local idx=$(( user_input - 1 ))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#video_list[@]} ]; then
      target_file="${video_list[$idx]}"
    else
      echo -e "${RED}  ✗ Nomor tidak valid.${RESET}"
      exit 1
    fi
  else
    # Cek nama file dengan berbagai ekstensi
    for ext in "${SUPPORTED_FORMATS[@]}"; do
      if [ -f "$SCRIPT_DIR/${user_input}.${ext}" ]; then
        target_file="${user_input}.${ext}"
        break
      fi
      # Case insensitive
      local found_file
      found_file=$(find "$SCRIPT_DIR" -maxdepth 1 -iname "${user_input}.${ext}" 2>/dev/null | head -1)
      if [ -n "$found_file" ]; then
        target_file="$(basename "$found_file")"
        break
      fi
    done

    # Coba dengan nama lengkap (sudah ada ekstensi)
    if [ -z "$target_file" ] && [ -f "$SCRIPT_DIR/$user_input" ]; then
      target_file="$user_input"
    fi

    if [ -z "$target_file" ]; then
      echo -e "${RED}  ✗ File '${user_input}' tidak ditemukan.${RESET}"
      echo -e "${DIM}  Pastikan nama benar dan file ada di folder yang sama dengan script.${RESET}"
      echo ""
      exit 1
    fi
  fi

  echo -e "  ${GREEN}✓ File ditemukan:${RESET} ${BOLD}$target_file${RESET}"

  compress_video "$SCRIPT_DIR/$target_file"
}

main "$@"
