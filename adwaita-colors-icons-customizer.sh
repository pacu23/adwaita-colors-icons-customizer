#!/bin/bash

# Script to create custom Adwaita icon theme with user-defined colors
# Creates theme in ~/.local/share/icons/Adwaita-custom
# Only copies SVG files that actually need recoloring; everything else is inherited.

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
        "$HOME/.local/share/icons/$theme_name"
        "$HOME/.icons/$theme_name"
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

# Function to generate darker color by 30%
generate_darker_color() {
    local color="$1"
    local darken_percent=30  # Darken by 30%
    
    # Remove # if present
    color="${color#\#}"
    
    # Convert hex to decimal for each component
    local r=$((16#${color:0:2}))
    local g=$((16#${color:2:2}))
    local b=$((16#${color:4:2}))
    
    # Darken each component by darken_percent
    local r_darker=$((r * (100 - darken_percent) / 100))
    local g_darker=$((g * (100 - darken_percent) / 100))
    local b_darker=$((b * (100 - darken_percent) / 100))
    
    # Convert back to hex with leading zeros
    printf "#%02x%02x%02x\n" $r_darker $g_darker $b_darker
}

# ============================================
# Create Adwaita-custom theme with color replacement
# ============================================

create_adwaita_custom() {
    local use_morewaita_apps="$1"
    
    print_status "=== Creating Adwaita-custom theme ==="
    
    # Find source directory
    SOURCE_DIR=$(find_icon_theme "Adwaita-teal")
    if [ $? -ne 0 ]; then
        print_error "Adwaita-teal icon theme not found in any of the expected locations."
        print_error "Searched in: ~/.local/share/icons, ~/.icons, /usr/share/icons, /usr/local/share/icons"
        print_error "Please install the Adwaita-teal icon theme first."
        return 1
    fi
    
    TARGET_DIR="$HOME/.local/share/icons/Adwaita-custom"
    
    print_status "Found Adwaita-teal at: $SOURCE_DIR"
    
    # Get user input for colors (dark first, then light)
    echo ""
    print_status "Enter colors for the Adwaita-custom theme"
    echo ""
    echo "Note:"
    echo "- Dark (accent) color could be your system accent color or any dark color"
    echo "- Light color should be very light (like the bottom color in Adwaita's folders)"
    echo "  for good contrast with the dark color"
    echo ""
    
    # Prompt for dark (accent) color FIRST
    while true; do
        read -p "Enter dark (accent) color (hex, e.g., #16a085 for green teal): " NEW_DARK_COLOR
        NEW_DARK_COLOR=$(validate_hex_color "$NEW_DARK_COLOR")
        if [ $? -eq 0 ]; then
            break
        else
            print_error "Invalid hex color. Please enter a valid 6-digit hex color (e.g., 16a085 or #16a085)."
        fi
    done
    
    # Prompt for light color SECOND
    while true; do
        read -p "Enter light color (hex, e.g., #a8d8cf for very light teal): " NEW_LIGHT_COLOR
        NEW_LIGHT_COLOR=$(validate_hex_color "$NEW_LIGHT_COLOR")
        if [ $? -eq 0 ]; then
            break
        else
            print_error "Invalid hex color. Please enter a valid 6-digit hex color (e.g., a8d8cf or #a8d8cf)."
        fi
    done
    
    # Generate darker color by darkening the dark color by 30%
    print_status "Generating darker color (30% darker than $NEW_DARK_COLOR)..."
    DARKER_COLOR=$(generate_darker_color "$NEW_DARK_COLOR")
    
    # Show color comparison
    echo ""
    print_status "Color Palette:"
    print_status "Light color:    $NEW_LIGHT_COLOR"
    print_status "Dark color:     $NEW_DARK_COLOR"
    print_status "Darker color:   $DARKER_COLOR (30% darker than dark)"
    echo ""
    
    # Remove target directory if it exists (clean start)
    if [ -d "$TARGET_DIR" ]; then
        print_status "Removing existing target directory"
        rm -rf "$TARGET_DIR"
    fi
    
    # Create target directory
    mkdir -p "$TARGET_DIR"
    
    # Copy and modify index.theme
    if [ -f "$SOURCE_DIR/index.theme" ]; then
        cp "$SOURCE_DIR/index.theme" "$TARGET_DIR/index.theme"
        print_status "Copied index.theme"
        
        # Update theme name
        sed -i 's/^Name=.*/Name=Adwaita-custom/' "$TARGET_DIR/index.theme"
        
        # Update Inherits line robustly (replace entire line)
        if [ "$use_morewaita_apps" = "yes" ]; then
            sed -i 's/^Inherits=.*/Inherits=MoreWaita,Adwaita,AdwaitaLegacy,hicolor/' "$TARGET_DIR/index.theme"
            print_status "Updated inherits to: MoreWaita,Adwaita,AdwaitaLegacy,hicolor"
        else
            sed -i 's/^Inherits=.*/Inherits=Adwaita,AdwaitaLegacy,hicolor/' "$TARGET_DIR/index.theme"
            print_status "Updated inherits to: Adwaita,AdwaitaLegacy,hicolor"
        fi
    else
        print_error "Source theme has no index.theme file!"
        return 1
    fi
    
    # Process SVG files - only copy those that contain any of the original colors
    print_status "Scanning for SVG files that need recoloring..."
    
    # Define original color patterns (from Adwaita-teal)
    # Dark patterns -> new dark color
    DARK_PATTERNS=(
        "#129eb0" "#2190a4" "#108094" "#1d8094" "#40c1d9" "#0f6c59"
    )
    # Darker patterns -> darker color
    DARKER_PATTERNS=(
        "#007184" "#08382e" "#1c7a8c"
    )
    # Light patterns -> new light color
    LIGHT_PATTERNS=(
        "#9edae6" "#7bdff4" "#3da7bc"
    )
    
    # Combine all patterns for the initial grep
    ALL_PATTERNS=("${DARK_PATTERNS[@]}" "${DARKER_PATTERNS[@]}" "${LIGHT_PATTERNS[@]}")
    
    # Build grep pattern (case-insensitive)
    GREP_PATTERN=$(printf "\\|%s" "${ALL_PATTERNS[@]}")
    GREP_PATTERN="${GREP_PATTERN:2}"  # remove leading "\|"
    
    # Find all SVG files in the source's scalable directory
    SOURCE_SCALABLE="$SOURCE_DIR/scalable"
    if [ ! -d "$SOURCE_SCALABLE" ]; then
        print_error "No 'scalable' directory found in source theme!"
        return 1
    fi
    
    # Use find to get all SVG files, then filter with grep
    # This is more efficient than checking each file individually
    mapfile -t SVG_FILES < <(find "$SOURCE_SCALABLE" -type f -name "*.svg")
    
    if [ ${#SVG_FILES[@]} -eq 0 ]; then
        print_warning "No SVG files found in scalable directory"
    else
        print_status "Found ${#SVG_FILES[@]} SVG files total. Identifying those containing original colors..."
        
        # Create associative array to mark files to copy
        declare -A FILES_TO_COPY
        
        # Use grep -l to list files that contain any pattern
        while IFS= read -r file; do
            # Get relative path from SOURCE_SCALABLE
            rel_path="${file#$SOURCE_SCALABLE/}"
            FILES_TO_COPY["$rel_path"]="$file"
        done < <(grep -l -i "$GREP_PATTERN" "${SVG_FILES[@]}" 2>/dev/null)
        
        copy_count=${#FILES_TO_COPY[@]}
        print_status "Found $copy_count SVG files containing original colors. Copying and recoloring..."
        
        if [ $copy_count -eq 0 ]; then
            print_warning "No SVG files contain the expected colors. Check the source theme."
            return 1
        fi
        
        # Process each file to copy and recolor
        processed=0
        for rel_path in "${!FILES_TO_COPY[@]}"; do
            src_file="${FILES_TO_COPY[$rel_path]}"
            target_file="$TARGET_DIR/scalable/$rel_path"
            
            # Create target directory
            mkdir -p "$(dirname "$target_file")"
            
            # Copy the file
            cp "$src_file" "$target_file"
            
            # Apply color replacements
            # Dark patterns -> NEW_DARK_COLOR
            for pattern in "${DARK_PATTERNS[@]}"; do
                sed -i "s/$pattern/$NEW_DARK_COLOR/gi" "$target_file"
            done
            
            # Darker patterns -> DARKER_COLOR
            for pattern in "${DARKER_PATTERNS[@]}"; do
                sed -i "s/$pattern/$DARKER_COLOR/gi" "$target_file"
            done
            
            # Light patterns -> NEW_LIGHT_COLOR
            for pattern in "${LIGHT_PATTERNS[@]}"; do
                sed -i "s/$pattern/$NEW_LIGHT_COLOR/gi" "$target_file"
            done
            
            # Special handling for Nautilus icon (fill-opacity)
            if [[ "$rel_path" == "apps/org.gnome.Nautilus.svg" ]]; then
                sed -i "s/fill-opacity:0\.69749063/fill-opacity:0.75/gi" "$target_file"
            fi
            
            ((processed++))
            if [ $((processed % 20)) -eq 0 ]; then
                echo -ne "  Processed $processed files...\r"
            fi
        done
        
        echo ""  # Clear the progress line
        print_status "Color replacement complete: processed $processed files"
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
    echo "If you choose 'yes', the Adwaita-custom theme will inherit from MoreWaita."
    echo "If you choose 'no', the Adwaita-custom theme will inherit only from Adwaita."
    echo ""
    
    while true; do
        read -p "Include MoreWaita app icons? (yes/no): " include_apps
        case "$include_apps" in
            yes|YES|y|Y)
                USE_MOREWAITA_APPS="yes"
                print_status "Will include MoreWaita in inherits (before Adwaita)"
                break
                ;;
            no|NO|n|N)
                USE_MOREWAITA_APPS="no"
                print_status "Will not include MoreWaita in inherits"
                break
                ;;
            *)
                print_error "Invalid input. Please enter 'yes' or 'no'."
                ;;
        esac
    done
    
    echo ""
    
    # Create Adwaita-custom theme
    create_adwaita_custom "$USE_MOREWAITA_APPS"
    
    echo ""
    echo "=========================================="
    print_status "Theme has been created successfully!"
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
echo "Theme is located in: $HOME/.local/share/icons/Adwaita-custom"
echo ""
echo "You can use GNOME Tweaks to switch to the Adwaita-custom theme."
