#!/usr/bin/env python3
"""Copies tools/web_head.html into the Web preset's html/head_include
(port ADR-119), so the page additions live in a file you can read.
test_lite checks the two match. Run after editing web_head.html:
    python3 game/tools/web_head.py
"""
import pathlib
import re

GAME = pathlib.Path(__file__).resolve().parent.parent
head = (GAME / "tools" / "web_head.html").read_text()
cfg_path = GAME / "export_presets.cfg"
cfg = cfg_path.read_text()
value = head.replace("\\", "\\\\").replace('"', '\\"')
line = 'html/head_include="%s"\n' % value
# the Web preset's options section: [preset.N.options] after name="Web"
web = re.search(r'\[preset\.(\d+)\]\n\nname="Web"', cfg)
assert web, "no Web preset"
sect = "[preset.%s.options]\n" % web.group(1)
start = cfg.index(sect) + len(sect)
end = cfg.find("\n[preset.", start)
end = len(cfg) if end < 0 else end + 1
body = re.sub(r'html/head_include="(?:[^"\\]|\\.)*"\n', "", cfg[start:end], flags=re.S)
body = body.replace("html/canvas_resize_policy=", line + "html/canvas_resize_policy=", 1)
assert line in body, "no html/canvas_resize_policy in the Web preset"
cfg_path.write_text(cfg[:start] + body + cfg[end:])
print("export_presets.cfg: html/head_include from tools/web_head.html")
