// Execute the exact state functions imported by QML, without pretending to run Qt.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');
const state = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../stow/desktop/.config/graphite/quick-settings/PopupState.js'), 'utf8'), state);
for (const page of ['wifi', 'bluetooth', 'audio', 'brightness', 'clipboard', 'displays', 'power']) {
    assert.equal(state.normalize(page), page);
    assert.equal(state.toggle(page, page), '');
}
assert.equal(state.normalize('mixer'), 'mixer');
assert.equal(state.toggle('mixer', 'audio'), '', 'audio bar trigger closes its mixer subpage');
assert.equal(state.toggle('mixer', 'wifi'), 'wifi');
assert.equal(state.normalize('power-settings'), 'power-settings');
assert.equal(state.toggle('power-settings', 'power'), '', 'battery trigger closes its settings subpage');
assert.equal(state.toggle('power-settings', 'audio'), 'audio');
assert.equal(state.normalize('audio'), 'audio', 'back navigation returns to devices');
assert.equal(state.normalize('home'), 'audio');
assert.equal(state.normalize('invalid'), 'audio');
for (const page of ['wifi', 'bluetooth', 'audio', 'brightness', 'clipboard']) {
    assert.equal(state.toggle(page, 'displays'), 'displays', 'separate top-level trigger replaces current page');
}
assert.equal(state.toggle('displays', 'home'), 'audio');
for (const current of ['wifi', 'bluetooth', 'audio', 'brightness', 'clipboard']) {
    for (const requested of ['wifi', 'bluetooth', 'audio', 'brightness', 'clipboard']) {
        assert.equal(state.toggle(current, requested), current === requested ? '' : requested);
    }
}
assert.equal(state.toggle('wifi', 'bluetooth'), 'bluetooth');
const layers = {
    'eDP-1': {levels: {'2': [{namespace: 'waybar', y: 6, h: 38}], '3': [{namespace: 'unrelated', y: 0, h: 768}]}},
    'HDMI-A-1': {levels: {'2': [{namespace: 'waybar', y: 0, h: 40}]}},
    'DP-2': {levels: {}}
};
assert.deepEqual(JSON.parse(JSON.stringify(state.barEdges(layers))), {'eDP-1': 44, 'HDMI-A-1': 40, 'DP-2': 0});
assert.throws(() => state.barEdges(null));
assert.throws(() => state.barEdges([]));
const first = {id: 'eDP-1', hyprId: 0, disabled: false, mirrorOf: 'none', x: 0, y: 0};
const second = {id: 'HDMI-A-1', hyprId: 7, disabled: false, mirrorOf: 'none', x: 1366, y: 0};
assert.equal(state.displayMode([first, second], 'eDP-1'), 'right');
assert.equal(state.displayMode([first, second], 'HDMI-A-1'), 'left');
assert.equal(state.displayMode([first, {...second, mirrorOf: '0', x: 0}], 'eDP-1'), 'mirror');
assert.equal(state.displayMode([{...first, mirrorOf: '7'}, second], 'eDP-1'), 'mirror');
assert.equal(state.displayMode([first, {...second, disabled: true}], 'eDP-1'), 'only');
assert.equal(state.displayMode([{...first, disabled: true}, second], 'eDP-1'), 'other');
assert.equal(state.displayMode([first, {...second, y: -1080}], 'eDP-1'), 'configure');
assert.equal(state.displayMode([first], 'eDP-1'), 'configure');
assert.equal(state.displayMode([], 'eDP-1'), 'configure');
assert.equal(state.displayMode([first, second], 'missing'), 'configure');
assert.equal(state.displayMode([first, second, {...second, id: 'DP-2'}], 'eDP-1'), 'configure');
assert.equal(first.mirrorOf, 'none', 'selection inspection never changes configuration');
console.log('PASS executable popup state tests: trigger close/switch, page normalization, per-output bar geometry, actual numeric mirror IDs, arrangement selection, missing/multiple outputs; no Qt or compositor exercised.');
