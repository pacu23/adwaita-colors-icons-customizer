#!/bin/bash

# Script to create modified icon themes
# Part 1: MoreWaita-noapps (conditional creation)
# Part 2: Adwaita-custom (copied with color replacements)

# Function to print plain output (no colors)
print_status() {
    echo "[+] $1"
}

print_error() {
    echo "[!] $1"
}

print_warning() {
    echo "[~] $1"
}

# Function to find icon theme in multiple locations
find_icon_theme() {
    local theme_name="$1"
    
    # Search in multiple locations (in order of preference)
    local search_paths=(
        "$HOME/.icons/$theme_name"
        "$HOME/.local/share/icons/$theme_name"
        "/usr/share/icons/$theme_name"
        "/usr/local/share/icons/$theme_name"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Function to validate hex color
validate_hex_color() {
    local color="$1"
    # Check if it's a valid 6-digit hex color (with or without #)
    if [[ "$color" =~ ^#?[0-9A-Fa-f]{6}$ ]]; then
        # Ensure it has the # prefix
        if [[ ! "$color" =~ ^# ]]; then
            color="#$color"
        fi
        echo "$color"
        return 0
    else
        return 1
    fi
}

# Function to generate darker color by applying same darkening ratio
generate_darker_color() {
    local light_color="$1"
    local dark_color="$2"
    
    # Remove # if present
    light_color="${light_color#\#}"
    dark_color="${dark_color#\#}"
    
    # Convert hex to decimal for each component
    local r_light=$((16#${light_color:0:2}))
    local g_light=$((16#${light_color:2:2}))
    local b_light=$((16#${light_color:4:2}))
    
    local r_dark=$((16#${dark_color:0:2}))
    local g_dark=$((16#${dark_color:2:2}))
    local b_dark=$((16#${dark_color:4:2}))
    
    # Calculate darkening ratio for each channel
    # Ratio = dark / light (as decimal)
    local r_ratio=$(echo "scale=3; $r_dark / $r_light" | bc)
    local g_ratio=$(echo "scale=3; $g_dark / $g_light" | bc)
    local b_ratio=$(echo "scale=3; $b_dark / $b_light" | bc)
    
    # Apply the same ratio to dark color to get darker color
    local r_darker=$(echo "$r_dark * $r_ratio" | bc | awk '{printf "%.0f", $1}')
    local g_darker=$(echo "$g_dark * $g_ratio" | bc | awk '{printf "%.0f", $1}')
    local b_darker=$(echo "$b_dark * $b_ratio" | bc | awk '{printf "%.0f", $1}')
    
    # Clamp values to 0-255
    r_darker=$(( r_darker < 0 ? 0 : (r_darker > 255 ? 255 : r_darker) ))
    g_darker=$(( g_darker < 0 ? 0 : (g_darker > 255 ? 255 : g_darker) ))
    b_darker=$(( b_darker < 0 ? 0 : (b_darker > 255 ? 255 : b_darker) ))
    
    # Convert back to hex with leading zeros
    printf "#%02x%02x%02x\n" $r_darker $g_darker $b_darker
}

# ============================================
# PART 1: Create MoreWaita-noapps theme (conditional)
# ============================================

create_morewaita_noapps() {
    print_status "=== Creating MoreWaita-noapps theme ==="
    
    # Find source directory
    SOURCE_DIR=$(find_icon_theme "MoreWaita")
    if [ $? -ne 0 ]; then
        print_error "MoreWaita icon theme not found in any of the expected locations."
        print_error "Searched in: ~/.icons, ~/.local/share/icons, /usr/share/icons, /usr/local/share/icons"
        return 1
    fi
    
    TARGET_DIR="$HOME/.icons/MoreWaita-noapps"
    
    print_status "Found MoreWaita at: $SOURCE_DIR"
    
    # Remove target directory if it exists (clean start)
    if [ -d "$TARGET_DIR" ]; then
        print_status "Removing existing target directory: $TARGET_DIR"
        rm -rf "$TARGET_DIR"
    fi
    
    # Create target directory
    mkdir -p "$TARGET_DIR"
    print_status "Created target directory: $TARGET_DIR"
    
    # Function to create parent directory structure
    create_parent_dirs() {
        local target_path="$1"
        local parent_dir
        parent_dir=$(dirname "$target_path")
        
        if [ ! -d "$parent_dir" ]; then
            mkdir -p "$parent_dir"
        fi
    }
    
    # Process all items in source directory
    print_status "Creating symlinks for all items except scalable and symbolic directories and index.theme..."
    
    # Find all items in source directory, excluding scalable, symbolic and index.theme for now
    find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 \( -name "scalable" -o -name "symbolic" -o -name "index.theme" \) -prune -o -print | while read -r item; do
        item_name=$(basename "$item")
        target_item="$TARGET_DIR/$item_name"
        
        # Create parent directory if needed (for nested structures)
        create_parent_dirs "$target_item"
        
        # Create symlink
        ln -sf "$item" "$target_item"
    done
    
    # Handle scalable directory specially
    SOURCE_SCALABLE="$SOURCE_DIR/scalable"
    TARGET_SCALABLE="$TARGET_DIR/scalable"
    
    if [ -d "$SOURCE_SCALABLE" ]; then
        print_status "Creating scalable directory structure (excluding apps)..."
        
        # Create scalable directory
        mkdir -p "$TARGET_SCALABLE"
        
        # Find all items in scalable directory except 'apps'
        find "$SOURCE_SCALABLE" -mindepth 1 -maxdepth 1 ! -name "apps" -print | while read -r item; do
            item_name=$(basename "$item")
            target_item="$TARGET_SCALABLE/$item_name"
            
            # Create symlink for each item in scalable (except apps)
            ln -sf "$item" "$target_item"
        done
        
        print_status "Excluded apps directory from scalable"
    else
        print_warning "Source scalable directory not found"
    fi
    
    # Handle symbolic directory specially - create directory and symlink subdirs except apps
    SOURCE_SYMBOLIC="$SOURCE_DIR/symbolic"
    TARGET_SYMBOLIC="$TARGET_DIR/symbolic"
    
    if [ -d "$SOURCE_SYMBOLIC" ]; then
        print_status "Creating symbolic directory structure (excluding apps)..."
        
        # Create symbolic directory (not symlink)
        mkdir -p "$TARGET_SYMBOLIC"
        
        # Find all items in symbolic directory except 'apps'
        find "$SOURCE_SYMBOLIC" -mindepth 1 -maxdepth 1 ! -name "apps" -print | while read -r item; do
            item_name=$(basename "$item")
            target_item="$TARGET_SYMBOLIC/$item_name"
            
            # Create symlink for each item in symbolic (except apps)
            ln -sf "$item" "$target_item"
        done
        
        print_status "Excluded apps directory from symbolic"
    else
        print_warning "Source symbolic directory not found"
    fi
    
    # Handle index.theme - copy and modify
    INDEX_SOURCE="$SOURCE_DIR/index.theme"
    INDEX_TARGET="$TARGET_DIR/index.theme"
    
    if [ -f "$INDEX_SOURCE" ]; then
        print_status "Copying and modifying index.theme..."
        
        # Copy the file (not symlink)
        cp "$INDEX_SOURCE" "$INDEX_TARGET"
        
        # Change Name=MoreWaita to Name=MoreWaita-noapps
        sed -i 's/^Name=MoreWaita$/Name=MoreWaita-noapps/' "$INDEX_TARGET"
        
        # Comment out Inherits line (with or without trailing spaces)
        sed -i 's/^Inherits=Adwaita,AdwaitaLegacy,hicolor$/#Inherits=Adwaita,AdwaitaLegacy,hicolor/' "$INDEX_TARGET"
        
        # Also handle any other possible variations (case-insensitive)
        sed -i 's/^[Ii]nherits=.*$/#&/' "$INDEX_TARGET" 2>/dev/null || true
        
        print_status "Modified index.theme"
    else
        print_warning "index.theme not found in source directory"
    fi
    
    print_status "MoreWaita-noapps theme created successfully"
    return 0
}

# ============================================
# PART 2: Create Adwaita-custom theme with color replacement
# ============================================

create_adwaita_custom() {
    local use_morewaita_apps="$1"
    
    print_status "=== Creating Adwaita-custom theme ==="
    
    # Find source directory
    SOURCE_DIR=$(find_icon_theme "Adwaita-teal")
    if [ $? -ne 0 ]; then
        print_error "Adwaita-teal icon theme not found in any of the expected locations."
        print_error "Searched in: ~/.icons, ~/.local/share/icons, /usr/share/icons, /usr/local/share/icons"
        print_error "Please install the Adwaita-teal icon theme first."
        return 1
    fi
    
    TARGET_DIR="$HOME/.icons/Adwaita-custom"
    
    print_status "Found Adwaita-teal at: $SOURCE_DIR"
    
    # Get user input for new colors
    echo ""
    print_status "Enter colors for the Adwaita-custom theme"
    echo ""
    echo "Note:"
    echo "- Light color should be very light (like the bottom color in Adwaita's folders)"
    echo "  for good contrast with the dark color"
    echo "- Dark (accent) color could be your system accent color or any dark color"
    echo ""
    
    # Prompt for light color
    while true; do
        read -p "Enter light color (hex, e.g., #e8f6f3 for very light teal): " NEW_LIGHT_COLOR
        NEW_LIGHT_COLOR=$(validate_hex_color "$NEW_LIGHT_COLOR")
        if [ $? -eq 0 ]; then
            break
        else
            print_error "Invalid hex color. Please enter a valid 6-digit hex color (e.g., e8f6f3 or #e8f6f3)."
        fi
    done
    
    # Prompt for dark (accent) color
    while true; do
        read -p "Enter dark (accent) color (hex, e.g., #16a085 for teal): " NEW_DARK_COLOR
        NEW_DARK_COLOR=$(validate_hex_color "$NEW_DARK_COLOR")
        if [ $? -eq 0 ]; then
            break
        else
            print_error "Invalid hex color. Please enter a valid 6-digit hex color (e.g., 16a085 or #16a085)."
        fi
    done
    
    # Generate darker color using the same darkening ratio
    print_status "Generating darker color based on the darkening ratio between light and dark colors..."
    DARKER_COLOR=$(generate_darker_color "$NEW_LIGHT_COLOR" "$NEW_DARK_COLOR")
    print_status "Generated darker color: $DARKER_COLOR"
    
    # Remove target directory if it exists (clean start)
    if [ -d "$TARGET_DIR" ]; then
        print_status "Removing existing target directory"
        rm -rf "$TARGET_DIR"
    fi
    
    # Copy entire theme (not symlink)
    print_status "Copying Adwaita-teal theme..."
    cp -r "$SOURCE_DIR" "$TARGET_DIR"
    
    # Update the theme name in index.theme
    INDEX_FILE="$TARGET_DIR/index.theme"
    if [ -f "$INDEX_FILE" ]; then
        sed -i 's/^Name=Adwaita-teal$/Name=Adwaita-custom/' "$INDEX_FILE"
        
        # Update inherits based on user choice - keep hicolor
        if [ "$use_morewaita_apps" = "yes" ]; then
            # User wants MoreWaita app icons
            sed -i 's/^Inherits=MoreWaita,Adwaita,Adwaita-blue,AdwaitaLegacy,hicolor$/Inherits=MoreWaita,Adwaita,AdwaitaLegacy,hicolor/' "$INDEX_FILE"
            print_status "Updated inherits to: MoreWaita,Adwaita,AdwaitaLegacy,hicolor"
        else
            # User doesn't want MoreWaita app icons
            sed -i 's/^Inherits=MoreWaita,Adwaita,Adwaita-blue,AdwaitaLegacy,hicolor$/Inherits=MoreWaita-noapps,Adwaita,AdwaitaLegacy,hicolor/' "$INDEX_FILE"
            print_status "Updated inherits to: MoreWaita-noapps,Adwaita,AdwaitaLegacy,hicolor"
        fi
        
        print_status "Updated theme name in index.theme"
    fi
    
    # Process SVG files - find all SVG files in scalable subdirectories
    print_status "Processing SVG files to replace colors..."
    
    # Find all SVG files in scalable directory and its subdirectories
    SVG_FILES=$(find "$TARGET_DIR/scalable" -name "*.svg" -type f)
    SVG_COUNT=$(echo "$SVG_FILES" | wc -l)
    
    if [ "$SVG_COUNT" -eq 0 ]; then
        print_warning "No SVG files found in scalable directory"
    else
        print_status "Found $SVG_COUNT SVG files to process"
        
        # Process each SVG file
        processed=0
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                # Use sed to replace colors
                # Dark colors (#129eb0) -> user's dark (accent) color
                sed -i "s/#129eb0/$NEW_DARK_COLOR/gi" "$file"
                
                # Middle colors (#2190a4, #108094, #1d8094) -> user's dark (accent) color
                sed -i "s/#2190a4/$NEW_DARK_COLOR/gi" "$file"
                sed -i "s/#108094/$NEW_DARK_COLOR/gi" "$file"
                sed -i "s/#1d8094/$NEW_DARK_COLOR/gi" "$file"
                
                # Darker colors (#007184) -> generated darker color
                sed -i "s/#007184/$DARKER_COLOR/gi" "$file"
                
                # #40c1d9 -> user's dark (accent) color (FIXED)
                sed -i "s/#40c1d9/$NEW_DARK_COLOR/gi" "$file"
                
                # Light colors -> user's light color
                sed -i "s/#9edae6/$NEW_LIGHT_COLOR/gi" "$file"
                sed -i "s/#7bdff4/$NEW_LIGHT_COLOR/gi" "$file"
                sed -i "s/#3da7bc/$NEW_LIGHT_COLOR/gi" "$file"
                
                ((processed++))
                
                # Show progress every 50 files
                if [ $((processed % 50)) -eq 0 ]; then
                    echo -ne "  Processed $processed files...\r"
                fi
            fi
        done <<< "$SVG_FILES"
        
        echo ""  # Clear the progress line
        print_status "Color replacement complete: processed $SVG_COUNT files"
    fi
    
    # Special handling for Nautilus icon
    NAUTILUS_FILE="$TARGET_DIR/scalable/apps/org.gnome.Nautilus.svg"
    if [ -f "$NAUTILUS_FILE" ]; then
        print_status "Applying special fixes to Nautilus icon..."
        
        # Replace the specific colors found in the SVG
        # 1. #08382e -> generated darker color
        sed -i "s/#08382e/$DARKER_COLOR/gi" "$NAUTILUS_FILE"
        
        # 2. #0f6c59 -> user's dark (accent) color
        sed -i "s/#0f6c59/$NEW_DARK_COLOR/gi" "$NAUTILUS_FILE"
        
        # 3. #1c7a8c -> generated darker color with 0.5 opacity (changed from 0.7 to 0.5)
        sed -i "s/#1c7a8c/$DARKER_COLOR/gi" "$NAUTILUS_FILE"
        
        # Change the opacity to 0.5 instead of the original 0.69749063
        sed -i "s/fill-opacity:0\.69749063/fill-opacity:0.5/gi" "$NAUTILUS_FILE"
        
        # Also target any other variations
        sed -i "s/fill:#1c7a8c/fill:$DARKER_COLOR/gi" "$NAUTILUS_FILE"
        
        print_status "Nautilus icon colors replaced:"
        echo "  #08382e -> $DARKER_COLOR"
        echo "  #0f6c59 -> $NEW_DARK_COLOR"
        echo "  #1c7a8c -> $DARKER_COLOR (with 0.5 opacity)"
    else
        print_warning "Nautilus icon not found at $NAUTILUS_FILE"
    fi
    
    print_status "Adwaita-custom theme created successfully"
    return 0
}

# ============================================
# Main script execution
# ============================================

main() {
    echo "=========================================="
    echo "Icon Theme Customization Script"
    echo "=========================================="
    echo ""
    
    # Ask user about MoreWaita app icons
    echo "Do you want to include MoreWaita app icons in the theme?"
    echo "If you choose 'no', a MoreWaita-noapps theme will be created without app icons,"
    echo "and the Adwaita-custom theme will inherit from MoreWaita-noapps."
    echo "If you choose 'yes', the Adwaita-custom theme will inherit from the original MoreWaita."
    echo ""
    
    while true; do
        read -p "Include MoreWaita app icons? (yes/no): " include_apps
        case "$include_apps" in
            yes|YES|y|Y)
                USE_MOREWAITA_APPS="yes"
                print_status "Using original MoreWaita with app icons"
                break
                ;;
            no|NO|n|N)
                USE_MOREWAITA_APPS="no"
                print_status "Creating MoreWaita-noapps theme without app icons"
                break
                ;;
            *)
                print_error "Invalid input. Please enter 'yes' or 'no'."
                ;;
        esac
    done
    
    echo ""
    
    # Create MoreWaita-noapps theme only if user said no to app icons
    if [ "$USE_MOREWAITA_APPS" = "no" ]; then
        create_morewaita_noapps
        echo ""
    else
        print_status "Skipping MoreWaita-noapps creation"
    fi
    
    # Create Adwaita-custom theme
    create_adwaita_custom "$USE_MOREWAITA_APPS"
    
    echo ""
    echo "=========================================="
    print_status "Themes have been created successfully!"
    echo ""
    
    # Ask if user wants to apply Adwaita-custom theme
    apply_theme_prompt
}

# Function to prompt for theme application (only Adwaita-custom now)
apply_theme_prompt() {
    echo "Would you like to apply the Adwaita-custom theme now?"
    echo "1) Yes, apply Adwaita-custom theme"
    echo "2) No, not now"
    
    while true; do
        read -p "Enter your choice (1-2): " choice
        
        case $choice in
            1)
                print_status "Applying Adwaita-custom theme..."
                gsettings set org.gnome.desktop.interface icon-theme "Adwaita-custom"
                print_status "Theme applied! You may need to restart applications to see changes."
                break
                ;;
            2)
                print_status "No theme applied. You can apply it later using GNOME Tweaks or:"
                echo "  gsettings set org.gnome.desktop.interface icon-theme 'Adwaita-custom'"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Check if running as non-root
if [ "$EUID" -eq 0 ]; then 
    print_error "This script should not be run as root/sudo."
    print_error "Please run it as a regular user."
    exit 1
fi

# Run main function
main

echo ""
print_status "Script completed successfully!"
echo "Themes are located in: $HOME/.icons/"
echo ""
echo "You can also use GNOME Tweaks to switch between themes."
