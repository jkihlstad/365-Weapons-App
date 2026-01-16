#!/usr/bin/env python3
"""
Generate 365Weapons Admin App Icon - iOS Liquid Glass Style
Run: python3 generate_icon.py

Requires: pip install pillow cairosvg
Or use alternative methods below.
"""

import subprocess
import sys
import os

def check_dependencies():
    """Check and suggest installation of required tools."""
    print("Checking available conversion methods...\n")

    methods = []

    # Check for cairosvg (Python)
    try:
        import cairosvg
        methods.append("cairosvg")
        print("✓ cairosvg available")
    except ImportError:
        print("✗ cairosvg not installed (pip install cairosvg)")

    # Check for Inkscape
    result = subprocess.run(["which", "inkscape"], capture_output=True)
    if result.returncode == 0:
        methods.append("inkscape")
        print("✓ Inkscape available")
    else:
        print("✗ Inkscape not installed (brew install inkscape)")

    # Check for rsvg-convert
    result = subprocess.run(["which", "rsvg-convert"], capture_output=True)
    if result.returncode == 0:
        methods.append("rsvg")
        print("✓ rsvg-convert available")
    else:
        print("✗ rsvg-convert not installed (brew install librsvg)")

    # Check for ImageMagick
    result = subprocess.run(["which", "convert"], capture_output=True)
    if result.returncode == 0:
        methods.append("imagemagick")
        print("✓ ImageMagick available")
    else:
        print("✗ ImageMagick not installed (brew install imagemagick)")

    return methods

def convert_with_cairosvg(svg_path, png_path, size=1024):
    """Convert using cairosvg."""
    import cairosvg
    cairosvg.svg2png(url=svg_path, write_to=png_path, output_width=size, output_height=size)
    print(f"✓ Created {png_path} using cairosvg")

def convert_with_inkscape(svg_path, png_path, size=1024):
    """Convert using Inkscape CLI."""
    subprocess.run([
        "inkscape", svg_path,
        "--export-type=png",
        f"--export-filename={png_path}",
        f"--export-width={size}",
        f"--export-height={size}"
    ], check=True)
    print(f"✓ Created {png_path} using Inkscape")

def convert_with_rsvg(svg_path, png_path, size=1024):
    """Convert using rsvg-convert."""
    subprocess.run([
        "rsvg-convert", svg_path,
        "-w", str(size),
        "-h", str(size),
        "-o", png_path
    ], check=True)
    print(f"✓ Created {png_path} using rsvg-convert")

def convert_with_imagemagick(svg_path, png_path, size=1024):
    """Convert using ImageMagick."""
    subprocess.run([
        "convert", "-background", "none",
        "-density", "300",
        "-resize", f"{size}x{size}",
        svg_path, png_path
    ], check=True)
    print(f"✓ Created {png_path} using ImageMagick")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    svg_path = os.path.join(script_dir, "AppIcon.svg")

    # Output paths
    icon_dir = os.path.join(script_dir, "Assets.xcassets", "AppIcon.appiconset")
    png_1024 = os.path.join(icon_dir, "AppIcon-1024.png")

    if not os.path.exists(svg_path):
        print(f"Error: SVG not found at {svg_path}")
        sys.exit(1)

    # Ensure output directory exists
    os.makedirs(icon_dir, exist_ok=True)

    # Check available methods
    methods = check_dependencies()

    if not methods:
        print("\n" + "="*60)
        print("No conversion tools found. Install one of:")
        print("  pip install cairosvg")
        print("  brew install inkscape")
        print("  brew install librsvg")
        print("  brew install imagemagick")
        print("\nOr use online converter:")
        print("  https://cloudconvert.com/svg-to-png")
        print("="*60)
        sys.exit(1)

    print(f"\nConverting {svg_path}...")
    print(f"Output: {png_1024}\n")

    # Try each method
    for method in methods:
        try:
            if method == "cairosvg":
                convert_with_cairosvg(svg_path, png_1024)
            elif method == "inkscape":
                convert_with_inkscape(svg_path, png_1024)
            elif method == "rsvg":
                convert_with_rsvg(svg_path, png_1024)
            elif method == "imagemagick":
                convert_with_imagemagick(svg_path, png_1024)

            # Update Contents.json
            update_contents_json(icon_dir, "AppIcon-1024.png")

            print(f"\n✓ Icon generated successfully!")
            print(f"\nNext steps:")
            print(f"1. Open Xcode")
            print(f"2. Navigate to Assets.xcassets/AppIcon")
            print(f"3. Verify the icon appears correctly")
            print(f"4. Build and run to test")
            return

        except Exception as e:
            print(f"✗ {method} failed: {e}")
            continue

    print("\nAll conversion methods failed.")

def update_contents_json(icon_dir, filename):
    """Update the Contents.json for Xcode."""
    import json

    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    contents_path = os.path.join(icon_dir, "Contents.json")
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)

    print(f"✓ Updated {contents_path}")

if __name__ == "__main__":
    main()
