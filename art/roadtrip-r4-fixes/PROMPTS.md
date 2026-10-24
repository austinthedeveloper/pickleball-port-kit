# Round 4 generation and fixes

The built-in image generation tool was used for the dashboard ornament repair. Only the small repaired region was composited into the original v3 image; the rest remains pixel-identical.

## Dashboard edit prompt

Use case: precise-object-edit. EDIT ONLY the hula dashboard ornament in the supplied v3 backdrop. Remove the entire hula figurine and its base plus its little cast shadow at far left. Reconstruct the coastal road/window behind the upper portion and the sun-faded textured teal vinyl behind its base so it looks completely natural. Its dashboard spot must be plain textured vinyl. Keep EVERY OTHER THING unchanged: steering wheel, road, hills, sky, windscreen wipers, dashboard contours/texture, blank gauges, cassette deck, coffee cup, mirror with empty hook, composition, lighting, colors and warm rich painterly pixel-art style. No new ornaments, no blank flat panel, no text. Match original exact 960x540 registration. This is a tiny in-place repair, NOT a redesign.

## Other four images

These fixes follow the document's exact-pixel requirements rather than regenerating the artwork:

- Paper: remove contaminated edge pixels and re-register the existing six panels so fold centres are at x 300, 600, 900, 1200 and 1500.
- Gear: isolate the whole existing objects from the v3 high-resolution sheet by their alpha-connected shapes, excluding neighbouring objects; retain order and the empty NONE cell.
- Van: retain frames 1 and 5, rebuild frames 2–4 from the first frame, use clean integer quarter-turn hub rotations and the existing one-pixel body bob.
- Paints: extend recolouring to missed lower-body, bumper and trim pixels, restoring the original glass, tyres, lights and roof bag in protected regions. Keep alpha and the starting paint unchanged.
