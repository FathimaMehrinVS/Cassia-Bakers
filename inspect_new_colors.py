from PIL import Image

def analyze_pixels(path):
    img = Image.open(path)
    width, height = img.size
    print(f"\n--- Analysis for {path} ---")
    
    # Analyze vertical columns at 25%, 50%, 75% width
    for pct in [0.25, 0.5, 0.75]:
        x = int(width * pct)
        print(f"Col at {pct*100}% width (x={x}):")
        
        # We will print out the transition lines where color significantly changes
        prev_color = None
        start_y = 0
        for y in range(0, height, 10): # step by 10 pixels
            r, g, b = img.getpixel((x, y))[:3]
            # Simple color categorization
            if r > 240 and g > 240 and b > 240:
                color_type = "WHITE"
            elif r < 60 and g < 60 and b < 60:
                color_type = "DARK"
            elif abs(r - g) < 15 and abs(g - b) < 15 and r > 100 and r < 180:
                color_type = "GREY_BACKDROP"
            else:
                color_type = f"COLOR({r},{g},{b})"
                
            if color_type != prev_color:
                if prev_color is not None:
                    print(f"  y={start_y} to {y}: {prev_color}")
                prev_color = color_type
                start_y = y
        print(f"  y={start_y} to {height}: {prev_color}")

analyze_pixels(r"C:\Users\hp\.gemini\antigravity-ide\brain\0f18b01e-31b8-4d53-a8f9-e8a05d5c1d5a\media__1781918016375.jpg")
analyze_pixels(r"C:\Users\hp\.gemini\antigravity-ide\brain\0f18b01e-31b8-4d53-a8f9-e8a05d5c1d5a\media__1781918016377.jpg")
