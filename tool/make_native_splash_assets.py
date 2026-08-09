from PIL import Image
import os

base = r"c:\xampp\htdocs\prism_mobile\assets\images"
out_dir = base

# --- 1) Centered splash logo (white PaAyo, trimmed) ---
logo = Image.open(os.path.join(base, "paayo_logo_white.png")).convert("RGBA")
bbox = logo.getbbox()
logo = logo.crop(bbox)
pad = 48
canvas = Image.new("RGBA", (logo.width + pad * 2, logo.height + pad * 2), (0, 0, 0, 0))
canvas.paste(logo, (pad, pad), logo)

target = 900
scale = min(target / canvas.width, target / canvas.height)
nw, nh = int(canvas.width * scale), int(canvas.height * scale)
logo_scaled = canvas.resize((nw, nh), Image.Resampling.LANCZOS)
splash_logo = Image.new("RGBA", (target, target), (0, 0, 0, 0))
splash_logo.paste(logo_scaled, ((target - nw) // 2, (target - nh) // 2), logo_scaled)
logo_path = os.path.join(out_dir, "native_splash_logo.png")
splash_logo.save(logo_path, "PNG")
print("wrote", logo_path, splash_logo.size)

# --- 2) Buildings branding from splash_paayo_buildings.png ---
src = Image.open(os.path.join(base, "splash_paayo_buildings.png")).convert("RGBA")
w, h = src.size
top = int(h * 0.62)
left, right, bottom = 8, w - 8, h - 8
band = src.crop((left, top, right, bottom))

pixels = band.load()
bw, bh = band.size
for y in range(bh):
    for x in range(bw):
        r, g, b, a = pixels[x, y]
        if r > 235 and g > 235 and b > 235:
            pixels[x, y] = (0, 0, 0, 0)
        elif r > 200 and g > 220 and b > 235 and abs(r - b) < 40:
            pixels[x, y] = (0, 0, 0, 0)

bb = band.getbbox()
if bb:
    band = band.crop(bb)

brand_w, brand_h = 1000, 420
brand = Image.new("RGBA", (brand_w, brand_h), (0, 0, 0, 0))
scale = min((brand_w * 0.92) / band.width, (brand_h * 0.95) / band.height)
bw2, bh2 = int(band.width * scale), int(band.height * scale)
band2 = band.resize((bw2, bh2), Image.Resampling.LANCZOS)
brand.paste(band2, (12, brand_h - bh2 - 4), band2)
brand_path = os.path.join(out_dir, "native_splash_buildings.png")
brand.save(brand_path, "PNG")
print("wrote", brand_path, brand.size, "buildings", band2.size)

# Android 12 centered logo (safe circle area)
a12 = Image.new("RGBA", (1152, 1152), (0, 0, 0, 0))
inner = int(1152 * 0.55)
max_side = max(logo_scaled.width, logo_scaled.height)
ls = logo_scaled.resize(
    (
        int(logo_scaled.width * inner / max_side),
        int(logo_scaled.height * inner / max_side),
    ),
    Image.Resampling.LANCZOS,
)
a12.paste(ls, ((1152 - ls.width) // 2, (1152 - ls.height) // 2), ls)
a12_path = os.path.join(out_dir, "native_splash_android12.png")
a12.save(a12_path, "PNG")
print("wrote", a12_path, a12.size)
