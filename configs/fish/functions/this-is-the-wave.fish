function __this_is_the_wave_usage
  echo "🎹🦞 THIS IS THE WAVE"
  echo "─────────────────────────────────"
  echo ""
  echo "Usage: this-is-the-wave [1-5 | filename]"
  echo ""
  echo "Tracks:"
  set i 1
  for f in (find "$HOME/Projects/active/this-is-the-wave/tracks" -maxdepth 1 -name '*.rb' | sort)
    echo "  $i. "(basename $f .rb)
    set i (math $i + 1)
  end
end

function this-is-the-wave --description 'This Is The Wave EP — 5-track synthwave Sonic Pi set'
  set tracks_dir "$HOME/Projects/active/this-is-the-wave/tracks"
  set target ""

  if test (count $argv) -gt 0
    if string match -qr '^[1-5]$' $argv[1]
      set i (math $argv[1] - 1)
      set target (find "$tracks_dir" -maxdepth 1 -name '*.rb' | sort | sed -n (math (math $i + 1))p)
    else
      set target (find "$tracks_dir" -iname "*$argv[1]*.rb" | head -1)
    end
  end

  if test -z "$target"
    __this_is_the_wave_usage
    return 1
  end

  echo "▶ "(basename $target .rb)" — paste into a fresh Sonic Pi buffer:"
  echo ""
  cat "$target"
end
