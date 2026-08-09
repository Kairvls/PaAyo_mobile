from PIL import Image
import os

base = r"c:\xampp\htdocs\prism_mobile\assets\images"
src = Image.open(os.path.join(base, "splash_paayo_buildings.png")).convert("RGBA")
w, h = src.size

# Take lower skyline portion (buildings only)
band = src.crop((6, int(h * 0.58), w - 6, h - 6))
px = band.load()
bw, bh = band.size
for y in range(bh):
    for x in range(bw):
        r, g, b, a = px[x, y]
        if r > 232 and g > 232 and b > 232:
            px[x, y] = (0, 0, 0, 0)
        elif r > 195 and g > 215 and b > 230 and abs(r - b) < 45:
            px[x, y] = (0, 0, 0, 0)

bb = band.getbbox()
if bb:
    band = band.crop(bb)

# Brighten for navy background
px = band.load()
bw, bh = band.size
for y in range(bh):
    for x in range(bw):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        px[x, y] = (
            min(255, int(r * 1.2 + 24)),
            min(255, int(g * 1.25 + 28)),
            min(255, int(b * 1.12 + 36)),
            a,
        )

# FoodGo-style: large bottom-left graphic on a tall transparent canvas
# Wide enough to spill past left/bottom edges when positioned.
canvas_w, canvas_h = 1400, 1100
out = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
# Scale buildings large — dominate bottom-left like the burgers
scale = min((canvas_w * 1.05) / band.width, (canvas_h * 0.98) / band.height)
nw, nh = int(band.width * scale), int(band.height * scale)
scaled = band.resize((nw, nh), Image.Resampling.LANCZOS)
# Anchor bottom-left, allow slight overflow left/bottom
out.paste(scaled, (-40, canvas_h - nh + 20), scaled)

path = os.path.join(base, "splash_buildings_hero.png")
out.save(path, "PNG")
print("wrote", path, out.size, "scaled", scaled.size)
