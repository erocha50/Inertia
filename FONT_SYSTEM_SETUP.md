# 🎨 Font Configuration System - Complete Setup

## ✅ System is Ready!

Your game now has a **professional font configuration system** that lets you drop fonts in and customize them without touching code!

---

## 🚀 Quick Start (What You Can Do Right Now)

### **To Change a Font:**

1. **Drop your .ttf or .otf font file** into the `res://fonts/` folder
   - Example: `MyAwesomeFont.ttf`

2. **Open the Font Config** 
   - In Godot Editor: Double-click `res://Resources/font_config.tres`
   - This opens the Inspector with all font settings

3. **Update the path and size**
   - Click the folder icon next to any font path
   - Select your new font from `res://fonts/`
   - Adjust the size slider as needed
   - Changes apply **instantly** when you save!

---

## 📋 What Was Created

### **Files Added:**
- ✅ `res://Scripts/FontConfig.gd` - The font management system
- ✅ `res://Resources/font_config.tres` - Your font configuration resource
- ✅ `res://FONTS_GUIDE.md` - Detailed documentation
- ✅ `res://FONTS_QUICK_START.txt` - Quick reference card

### **Files Modified:**
- ✅ `res://Scripts/main_menu.gd` - Now loads fonts from config

---

## 🎯 Font Configuration Properties

The `font_config.tres` resource has these **editable properties**:

| Property | Default | Purpose |
|----------|---------|---------|
| `title_font_path` | `res://fonts/BebasNeue-Regular.ttf` | Font for "INERTIA" title |
| `title_font_size` | 72 | Size of title text |
| `subtitle_font_path` | `res://fonts/BebasNeue-Regular.ttf` | Font for subtitle |
| `subtitle_font_size` | 16 | Size of subtitle text |
| `button_font_path` | `res://fonts/BebasNeue-Regular.ttf` | Font for buttons |
| `button_font_size` | 24 | Size of button text |
| `status_font_path` | `res://fonts/BebasNeue-Regular.ttf` | Font for status text |
| `status_font_size` | 14 | Size of status text |
| `version_font_path` | `res://fonts/BebasNeue-Regular.ttf` | Font for version info |
| `version_font_size` | 10 | Size of version text |

---

## 📂 Folder Structure

```
Your Project/
├── res://
│   ├── fonts/                          ← Drop .ttf/.otf files here!
│   │   └── BebasNeue-Regular.ttf      (existing)
│   │
│   ├── Scripts/
│   │   ├── FontConfig.gd              ← Font system script
│   │   └── main_menu.gd               ← Uses FontConfig
│   │
│   ├── Resources/
│   │   └── font_config.tres           ← Edit this in Inspector!
│   │
│   └── Scenes/
│       └── main_menu.tscn             ← Uses fonts from config
```

---

## 🎨 Customization Examples

### **Using Different Fonts for Different UI Elements**

**Bold Title + Clean Buttons:**
1. Download "Orbitron" bold font → drop in `res://fonts/Orbitron.ttf`
2. Download "JetBrains Mono" → drop in `res://fonts/JetBrainsMono.ttf`
3. Edit `font_config.tres`:
   - `title_font_path` = `res://fonts/Orbitron.ttf`
   - `button_font_path` = `res://fonts/JetBrainsMono.ttf`
   - Done! ✨

### **Recommended Font Sizes**
- **Title**: 60-80px (big, impressive)
- **Subtitle**: 14-18px (readable but smaller)
- **Buttons**: 20-28px (easy to read, tap-friendly)
- **Status**: 10-14px (small, unobtrusive)

### **Font Pairing Suggestions**
- **Elegant + Tech**: Prata (title) + Space Mono (buttons)
- **Gaming + Bold**: Bebas Neue (title) + Courier New (buttons)
- **Futuristic**: Orbitron (title) + IBM Plex Mono (buttons)
- **Clean**: Montserrat (title) + Roboto Mono (buttons)

---

## 🔍 How It Works (Technical Details)

### **Font Loading Flow:**
```
Game Starts
    ↓
MainMenu._ready() 
    ↓
Loads font_config.tres resource
    ↓
_apply_fonts() assigns fonts to UI elements
    ↓
Each label/button gets custom font from config
    ↓
Your custom fonts are displayed! ✨
```

### **Font Caching:**
- Fonts are cached after first load (better performance)
- Same font file used multiple times = loaded once
- No performance penalty for multiple UI elements

---

## ✨ Features

✅ **Drop-and-Go**: Just drop .ttf/.otf files in `res://fonts/`  
✅ **Visual Inspector**: Edit fonts in the Inspector without coding  
✅ **Instant Updates**: Changes apply when you save  
✅ **Flexible**: Different fonts for title, buttons, status  
✅ **Cached**: Efficient font loading with caching  
✅ **Fallback Safe**: Automatically handles missing fonts  

---

## 🐛 Troubleshooting

### **Font Not Showing?**
- **Solution**: Check the file path is exactly `res://fonts/YourFont.ttf`
- Verify the file actually exists in the folder
- Try a different font to test

### **Text Looks Blurry?**
- **Solution**: Increase the font size in the config
- Fonts below 10px can look blurry at normal DPI

### **Getting Font Errors in Console?**
- Check that the file path is correct
- Make sure you're using .ttf or .otf format
- Avoid special characters in font filenames

### **Want to Reset Everything?**
- Edit `res://Resources/font_config.tres`
- Change all paths back to: `res://fonts/BebasNeue-Regular.ttf`
- Reset sizes: title=72, subtitle=16, buttons=24, status=14, version=10

---

## 📚 Additional Resources

- **FONTS_GUIDE.md** - Detailed documentation with all settings
- **FONTS_QUICK_START.txt** - Quick reference card
- **Google Fonts**: https://fonts.google.com (free fonts)
- **DaFont**: https://www.dafont.com (free fonts)

---

## 🎓 For Developers

### **Using FontConfig in Your Own Scripts**

```gdscript
# Load the font config
var font_config: FontConfig = load("res://Resources/font_config.tres")

# Get a font
var button_font: Font = font_config.get_button_font()
var button_size: int = font_config.button_font_size

# Apply to your UI
my_button.add_theme_font_override("font", button_font)
my_button.add_theme_font_size_override("font_size", button_size)
```

### **Adding New Font Types**

Edit `res://Scripts/FontConfig.gd` and add:
```gdscript
@export var custom_font_path: String = "res://fonts/Default.ttf"
@export var custom_font_size: int = 16

func get_custom_font() -> Font:
	if _custom_font_cache == null:
		_custom_font_cache = _load_font(custom_font_path)
	return _custom_font_cache
```

---

## 🎉 You're All Set!

Your game now has a **professional, flexible font system** that's:
- ✅ Easy to use (no coding needed!)
- ✅ Visually editable in the Inspector
- ✅ Optimized with font caching
- ✅ Scalable for future UI elements

**Time to make your menu look amazing!** 🚀
