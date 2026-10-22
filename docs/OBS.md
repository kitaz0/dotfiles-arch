# Recording

**Super+O uses OBS Studio; Super+Shift+R uses wf-recorder.** They are independent.

```bash
pacman -Q obs-studio wf-recorder
bash install-deps.sh --review --optional=obs
```

Review/run the printed package command yourself. OBS is optional and is not installed by configuration deployment.

## Quick recording

Super+Shift+R selects a region; press again to stop/finalize. Files go to `~/Videos/Recordings/`. The helper uses software x264, MKV, no audio, and a systemd user unit receiving SIGINT on stop. Its unique output filename is reserved first; `-y` permits writing that specific empty file without an interactive overwrite prompt.

```bash
bash ~/.local/lib/graphite/record.sh status
journalctl --user -b -u graphite-recorder.service --no-pager -n 60
```

Missing dependencies, encoder failures and compositor capture failures are distinct. An accepted service launch does not prove frames were captured. Record 20 seconds and play the file back.

## OBS

1. Open OBS. Choose a recording folder and MKV format.
2. Add a **Screen Capture (PipeWire)** source and select a screen/window in the portal chooser.
3. Start with software x264. Only enable hardware encoding after checking actual device/encoder support.
4. Add microphone/output audio sources supported by your build; confirm meters move and avoid duplicate audio sources.
5. Record a short sample with motion, speech and desktop sound. Stop normally and verify playback, sync and dropped frames.

Check `wpctl status` and `systemctl --user status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service`. Do not replace working audio services or set global GPU/VA-API overrides merely to troubleshoot OBS.

Implementation reference: [wf-recorder overwrite option](https://github.com/ammen99/wf-recorder/blob/master/src/main.cpp).
