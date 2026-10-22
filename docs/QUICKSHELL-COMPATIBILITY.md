# Quickshell 0.3.2

Use the versioned documentation: [PanelWindow](https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/), [ObjectModel.values](https://quickshell.org/docs/v0.3.2/types/Quickshell/ObjectModel/), [Pipewire](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/Pipewire/).

Arch's generated metadata can omit ObjectModel.values, PanelWindow creation and margins. Only these documented source lines carry paired `qmllint disable/enable` annotations for the specific category. Syntax, imports, unrelated missing properties and other warnings remain enabled. This is a tooling workaround, not a runtime API replacement or proof of compatibility.

Actual code fixes use a typed Item cast for Loader focus and a shared clipboard action instead of invoking an unknown button signal through QQuickItem. No unused Quickshell import remains in ClipboardPage.

Run `bash verify-setup.sh`, then close/reopen settings from a terminal to see runtime diagnostics:

```bash
bash ~/.local/lib/graphite/quick-settings.sh close
bash ~/.local/lib/graphite/quick-settings.sh audio
```

[Qt documents scoped lint annotations](https://doc.qt.io/qt-6/qtqml-tooling-qmllint.html). Run lint and test popup loading on the target system; metadata checks alone do not validate runtime behavior.
