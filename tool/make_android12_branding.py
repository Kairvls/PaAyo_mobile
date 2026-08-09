from PIL import Image
import os

base = r"c:\xampp\htdocs\prism_mobile\assets\images"

# Source buildings (transparent skyline)
src = Image.open(os.path.join(base, "native_splash_buildings.png")).convert("RGBA")
bb = src.getbbox()
if bb:
    src = src.crop(bb)

# Android 12 branding must be 800x320
brand_w, brand_h = 800, 320
brand = Image.new("RGBA", (brand_w, brand_h), (0, 0, 0, 0))

# Fit skyline into bottom-left of the 800x320 canvas
scale = min((brand_w * 0.98) / src.width, (brand_h * 0.98) / src.height)
nw, nh = int(src.width * scale), int(src.height * scale)
scaled = src.resize((nw, nh), Image.Resampling.LANCZOS)

# Brighten slightly so it reads on navy #0F172A
pixels = scaled.load()
for y in range(nh):
    for x in range(nw):
        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        # lift blues toward cyan/light for contrast on navy
        r = min(255, int(r * 1.15 + 18))
        g = min(255, int(g * 1.2 + 22))
        b = min(255, int(b * 1.1 + 30))
        pixels[x, y] = (r, g, b, a)

brand.paste(scaled, (8, brand_h - nh - 2), scaled)
out = os.path.join(base, "native_splash_buildings_a12.png")
brand.save(out, "PNG")
print("wrote", out, brand.size)
