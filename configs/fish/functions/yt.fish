# yt.fish — yt-dlp wrapper with sensible defaults
# Usage:
#   yt <url>              → best mp4 video + best mp3 audio, save to ~/Videos/yt/
#   yt --audio <url>      → extract audio only (mp3)
#   yt --playlist <url>   → download entire playlist
#   yt --subs <url>       → embed subtitles if available
#   yt --4k <url>         → prefer 4K/60fps
#   yt --live <url>       → live stream capture
#   yt --list             → list formats without downloading
#   yt <url> [extra args] → passthrough to yt-dlp

function yt --description 'yt-dlp wrapper with sane defaults'
    if not command -v yt-dlp >/dev/null 2>&1
        echo "yt-dlp not installed"
        return 1
    end

    set -l out_dir "$HOME/Videos/yt"
    mkdir -p "$out_dir"

    set -l url
    set -l mode video
    set -l extra

    # flag parsing
    if test (count $argv) -eq 0
        echo "Usage: yt [--audio|--playlist|--subs|--4k|--live|--list] <url> [yt-dlp args...]"
        return 1
    end

    for a in $argv
        switch $a
            case --audio
                set mode audio
            case --playlist
                set mode playlist
            case --subs
                set mode subs
            case --4k
                set mode 4k
            case --live
                set mode live
            case --list
                set mode list
            case '-*'
                set extra $extra $a
            case '*'
                set url $a
        end
    end

    if test -z "$url"
        echo "No URL given"
        return 1
    end

    set -l base_args -o "$out_dir" --merge-output-format mp4

    switch $mode
        case video
            yt-dlp $base_args -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" "$url" $extra
        case audio
            yt-dlp $base_args --extract-audio --audio-format mp3 --audio-quality 0 "$url" $extra
        case playlist
            yt-dlp $base_args --yes-playlist -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" "$url" $extra
        case subs
            yt-dlp $base_args --write-subs --sub-langs all --embed-subs -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" "$url" $extra
        case '4k'
            yt-dlp $base_args -f "bestvideo[height<=2160]+bestaudio[ext=m4a]/best[ext=mp4]" "$url" $extra
        case live
            yt-dlp $base_args --hls-use-mpegts --live-from-start "$url" $extra
        case list
            yt-dlp -F "$url" $extra
    end
end
