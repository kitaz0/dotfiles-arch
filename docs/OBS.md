# Recording

**Super+O uses OBS Studio; the quick-record shortcuts use wf-recorder.** OBS is managed independently.

```bash
pacman -Q obs-studio wf-recorder
bash install-deps.sh --review --optional=obs
```

Review/run the printed package command yourself. OBS is optional and is not installed by configuration deployment.

## Quick recording

| Shortcut | Starts when idle |
| --- | --- |
| Super+Shift+R | Selected region |
| Super+Ctrl+R | Entire focused monitor |
| Super+Alt+R | Active window rectangle |

While a quick recording is running, **any of these shortcuts stops and finalizes it**. It never switches modes or starts a second recording in the same keypress. Press again after stopping to start the requested mode. The common guard also excludes competing selectors and startup/stop transitions; all modes use `graphite-recorder.service`. Start and stop notifications name the recording mode, including when stopped with a shortcut for another mode.

Window recording is a screen crop of the initial visible window bounds on its assigned monitor. It does not follow moves/resizes or exclude windows covering that rectangle. The recorder may round odd video dimensions down by one pixel for encoder alignment. Keep the target stationary and unobscured; use OBS and a portal window source when you need a window-specific stream.

Files go to `~/Videos/Recordings/`. The helper uses software x264, MKV, no audio, and a systemd user unit receiving SIGINT on stop. Its unique output filename is reserved first; `-y` permits writing that specific empty file without an interactive overwrite prompt.

```bash
bash ~/.local/lib/graphite/record.sh start full
bash ~/.local/lib/graphite/record.sh stop
bash ~/.local/lib/graphite/record.sh start window
bash ~/.local/lib/graphite/record.sh status
journalctl --user -b -u graphite-recorder.service --no-pager -n 60
```

`record.sh --help` lists the commands. Explicit `start` refuses an existing recorder; `toggle` stops it. Region selection can be cancelled with Escape.

Missing dependencies, encoder failures and compositor capture failures are distinct. An accepted service launch does not prove frames were captured. Record 20 seconds and play the file back.

## OBS

1. Open OBS. Choose a recording folder and MKV format.
2. Add a **Screen Capture (PipeWire)** source and select a screen/window in the portal chooser.
3. Start with software x264. Only enable hardware encoding after checking actual device/encoder support.
4. Add microphone/output audio sources supported by your build; confirm meters move and avoid duplicate audio sources.
5. Record a short sample with motion, speech and desktop sound. Stop normally and verify playback, sync and dropped frames.

Check `wpctl status` and `systemctl --user status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service`. Do not replace working audio services or set global GPU/VA-API overrides merely to troubleshoot OBS.

Implementation reference: [wf-recorder overwrite option](https://github.com/ammen99/wf-recorder/blob/master/src/main.cpp).
