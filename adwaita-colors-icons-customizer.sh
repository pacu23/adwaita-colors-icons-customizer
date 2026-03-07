#!/bin/bash

# Script to create custom Adwaita icon theme with user-defined colors
# Creates theme in ~/.local/share/icons/Adwaita-custom
# Only copies SVG files that actually need recoloring; everything else is inherited.
# Optionally integrates MoreWaita by copying all its mimetype icons (resolving symlinks)
# while preserving recolored icons from Adwaita-teal.

# Function to print plain output (no colors)
print_status() { echo "[+] $1"; }
print_error() { echo "[!] $1"; }
print_warning() { echo "[~] $1"; }

# Function to find icon theme in multiple locations
find_icon_theme() {
    local theme_name="$1"
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
    if [[ "$color" =~ ^#?[0-9A-Fa-f]{6}$ ]]; then
        [[ ! "$color" =~ ^# ]] && color="#$color"
        echo "$color"
        return 0
    else
        return 1
    fi
}

# Function to generate darker color by 30%
generate_darker_color() {
    local color="$1"
    local darken_percent=30
    color="${color#\#}"
    local r=$((16#${color:0:2}))
    local g=$((16#${color:2:2}))
    local b=$((16#${color:4:2}))
    local r_darker=$((r * (100 - darken_percent) / 100))
    local g_darker=$((g * (100 - darken_percent) / 100))
    local b_darker=$((b * (100 - darken_percent) / 100))
    printf "#%02x%02x%02x\n" $r_darker $g_darker $b_darker
}

# ============================================
# Create Adwaita-custom theme
# ============================================
create_adwaita_custom() {
    local use_morewaita_apps="$1"

    print_status "=== Creating Adwaita-custom theme ==="

    SOURCE_DIR=$(find_icon_theme "Adwaita-teal")
    if [ $? -ne 0 ]; then
        print_error "Adwaita-teal icon theme not found."
        return 1
    fi
    TARGET_DIR="$HOME/.local/share/icons/Adwaita-custom"
    print_status "Found Adwaita-teal at: $SOURCE_DIR"

    # Color input
    echo ""
    print_status "Enter colors for the Adwaita-custom theme"
    echo ""
    while true; do
        read -p "Enter dark (accent) color (hex, e.g., #16a085): " NEW_DARK_COLOR
        NEW_DARK_COLOR=$(validate_hex_color "$NEW_DARK_COLOR") && break
        print_error "Invalid hex color."
    done
    while true; do
        read -p "Enter light color (hex, e.g., #a8d8cf): " NEW_LIGHT_COLOR
        NEW_LIGHT_COLOR=$(validate_hex_color "$NEW_LIGHT_COLOR") && break
        print_error "Invalid hex color."
    done
    DARKER_COLOR=$(generate_darker_color "$NEW_DARK_COLOR")
    echo ""
    print_status "Color Palette:"
    print_status "Light color:    $NEW_LIGHT_COLOR"
    print_status "Dark color:     $NEW_DARK_COLOR"
    print_status "Darker color:   $DARKER_COLOR"
    echo ""

    # Clean and create target
    [ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"

    # Copy and modify index.theme
    if [ -f "$SOURCE_DIR/index.theme" ]; then
        cp "$SOURCE_DIR/index.theme" "$TARGET_DIR/index.theme"
        sed -i 's/^Name=.*/Name=Adwaita-custom/' "$TARGET_DIR/index.theme"
        if [ "$use_morewaita_apps" = "yes" ]; then
            sed -i 's/^Inherits=.*/Inherits=MoreWaita,Adwaita,AdwaitaLegacy,hicolor/' "$TARGET_DIR/index.theme"
            print_status "Inherits set to: MoreWaita,Adwaita,AdwaitaLegacy,hicolor"
        else
            sed -i 's/^Inherits=.*/Inherits=Adwaita,AdwaitaLegacy,hicolor/' "$TARGET_DIR/index.theme"
            print_status "Inherits set to: Adwaita,AdwaitaLegacy,hicolor"
        fi
    else
        print_error "Source theme has no index.theme"
        return 1
    fi

    # Original color patterns
    DARK_PATTERNS=("#129eb0" "#2190a4" "#108094" "#1d8094" "#40c1d9" "#0f6c59")
    DARKER_PATTERNS=("#007184" "#08382e" "#1c7a8c")
    LIGHT_PATTERNS=("#9edae6" "#7bdff4" "#3da7bc")
    ALL_PATTERNS=("${DARK_PATTERNS[@]}" "${DARKER_PATTERNS[@]}" "${LIGHT_PATTERNS[@]}")
    GREP_PATTERN=$(printf "\\|%s" "${ALL_PATTERNS[@]}")
    GREP_PATTERN="${GREP_PATTERN:2}"

    SOURCE_SCALABLE="$SOURCE_DIR/scalable"
    if [ ! -d "$SOURCE_SCALABLE" ]; then
        print_error "No 'scalable' directory in source theme!"
        return 1
    fi

    # ----------------------------------------------------------------------
    # 1. Copy and recolor all SVG files that contain any of the original colors
    #    BUT skip GNOME Calendar (org.gnome.Calendar.svg)
    # ----------------------------------------------------------------------
    mapfile -t SVG_FILES < <(find "$SOURCE_SCALABLE" -type f -name "*.svg")
    if [ ${#SVG_FILES[@]} -eq 0 ]; then
        print_warning "No SVG files found."
    else
        print_status "Found ${#SVG_FILES[@]} SVG files. Identifying those with original colors..."
        declare -A FILES_TO_COPY
        while IFS= read -r file; do
            # Skip GNOME Calendar
            if [[ "$file" == *"/org.gnome.Calendar.svg" ]]; then
                continue
            fi
            rel_path="${file#$SOURCE_SCALABLE/}"
            FILES_TO_COPY["$rel_path"]="$file"
        done < <(grep -l -i "$GREP_PATTERN" "${SVG_FILES[@]}" 2>/dev/null)

        copy_count=${#FILES_TO_COPY[@]}
        print_status "Found $copy_count files containing original colors (excluding GNOME Calendar)."

        # Copy and recolor them
        processed=0
        for rel_path in "${!FILES_TO_COPY[@]}"; do
            src_file="${FILES_TO_COPY[$rel_path]}"
            target_file="$TARGET_DIR/scalable/$rel_path"
            mkdir -p "$(dirname "$target_file")"
            cp "$src_file" "$target_file"

            for pattern in "${DARK_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_DARK_COLOR/gi" "$target_file"; done
            for pattern in "${DARKER_PATTERNS[@]}"; do sed -i "s/$pattern/$DARKER_COLOR/gi" "$target_file"; done
            for pattern in "${LIGHT_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_LIGHT_COLOR/gi" "$target_file"; done

            if [[ "$rel_path" == "apps/org.gnome.Nautilus.svg" ]]; then
                sed -i "s/fill-opacity:0\.69749063/fill-opacity:0.5/gi" "$target_file"
            fi

            ((processed++))
            [ $((processed % 20)) -eq 0 ] && echo -ne "  Recolored $processed files...\r"
        done
        echo ""
        print_status "Recolored $processed files."
    fi

    # ----------------------------------------------------------------------
    # 2. Force the two generic script icons to be recolored (they may not contain patterns)
    # ----------------------------------------------------------------------
    GENERIC_ICONS=(
        "mimetypes/text-x-script.svg"
        "mimetypes/application-x-executable.svg"
    )
    print_status "Ensuring generic script icons are recolored..."
    for icon_rel in "${GENERIC_ICONS[@]}"; do
        target_file="$TARGET_DIR/scalable/$icon_rel"
        if [ ! -f "$target_file" ]; then
            src_file="$SOURCE_DIR/scalable/$icon_rel"
            if [ -f "$src_file" ]; then
                mkdir -p "$(dirname "$target_file")"
                cp "$src_file" "$target_file"
                for pattern in "${DARK_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_DARK_COLOR/gi" "$target_file"; done
                for pattern in "${DARKER_PATTERNS[@]}"; do sed -i "s/$pattern/$DARKER_COLOR/gi" "$target_file"; done
                for pattern in "${LIGHT_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_LIGHT_COLOR/gi" "$target_file"; done
                print_status "  Copied and recolored $icon_rel"
            else
                print_warning "  Source $icon_rel not found in Adwaita-teal; cannot recolor."
            fi
        else
            # Already present, but ensure recoloring
            print_status "  $icon_rel already present, ensuring recoloring..."
            for pattern in "${DARK_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_DARK_COLOR/gi" "$target_file"; done
            for pattern in "${DARKER_PATTERNS[@]}"; do sed -i "s/$pattern/$DARKER_COLOR/gi" "$target_file"; done
            for pattern in "${LIGHT_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_LIGHT_COLOR/gi" "$target_file"; done
        fi
    done

    # ----------------------------------------------------------------------
    # 3. Force explicit Adwaita-teal mimetypes to be present and recolored
    # ----------------------------------------------------------------------
    EXPLICIT_ADWAITA_FILES=(
        "oasis-web.svg"
        "text-html.svg"
        "libreoffice-web.svg"
        "libreoffice-oasis-web.svg"
        "application-vnd.google-apps.site.svg"
    )
    ADWAITA_MIME_SOURCE="$SOURCE_DIR/scalable/mimetypes"
    TARGET_MIME="$TARGET_DIR/scalable/mimetypes"
    mkdir -p "$TARGET_MIME"
    for file in "${EXPLICIT_ADWAITA_FILES[@]}"; do
        src_adw="$ADWAITA_MIME_SOURCE/$file"
        target_adw="$TARGET_MIME/$file"
        if [ -f "$src_adw" ] && [ ! -f "$target_adw" ]; then
            cp "$src_adw" "$target_adw"
            # Recolor it
            for pattern in "${DARK_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_DARK_COLOR/gi" "$target_adw"; done
            for pattern in "${DARKER_PATTERNS[@]}"; do sed -i "s/$pattern/$DARKER_COLOR/gi" "$target_adw"; done
            for pattern in "${LIGHT_PATTERNS[@]}"; do sed -i "s/$pattern/$NEW_LIGHT_COLOR/gi" "$target_adw"; done
            print_status "  Added explicit file $file from Adwaita-teal"
        fi
    done

    # ----------------------------------------------------------------------
    # 4. MoreWaita integration: copy all mimetype icons (resolving symlinks),
    #    but only if they don't already exist (preserve recolored ones)
    # ----------------------------------------------------------------------
    if [ "$use_morewaita_apps" = "yes" ]; then
        print_status "Integrating MoreWaita mimetypes (copying resolved files)..."

        MOREWAITA_DIR=$(find_icon_theme "MoreWaita")
        if [ -z "$MOREWAITA_DIR" ]; then
            print_warning "MoreWaita not found. Skipping."
        else
            print_status "Found MoreWaita at: $MOREWAITA_DIR"
            MOREWAITA_MIME="$MOREWAITA_DIR/scalable/mimetypes"
            if [ ! -d "$MOREWAITA_MIME" ]; then
                print_warning "MoreWaita mimetypes directory missing. Skipping."
            else
                TARGET_MIME="$TARGET_DIR/scalable/mimetypes"
                mkdir -p "$TARGET_MIME"

                copied=0
                skipped=0
                # Find both regular files and symlinks
                find "$MOREWAITA_MIME" -maxdepth 1 \( -type f -o -type l \) -name "*.svg" -print0 | while IFS= read -r -d '' src_file; do
                    base=$(basename "$src_file")
                    target="$TARGET_MIME/$base"

                    # Skip if target already exists (recolored version)
                    if [ -f "$target" ] || [ -L "$target" ]; then
                        ((skipped++))
                        continue
                    fi

                    # Resolve symlink to actual file and copy
                    if [ -L "$src_file" ]; then
                        resolved=$(readlink -f "$src_file")
                        if [ -f "$resolved" ]; then
                            cp "$resolved" "$target"
                            ((copied++))
                        else
                            print_warning "    Symlink target $resolved not found for $base; skipping."
                        fi
                    else
                        # Regular file: copy directly
                        cp "$src_file" "$target"
                        ((copied++))
                    fi

                    [ $((copied % 20)) -eq 0 ] && echo -ne "    Copied $copied MoreWaita icons...\r"
                done
                echo ""
                print_status "Added $copied icons from MoreWaita (copied resolved files), skipped $skipped (preserved recolored)."
            fi
        fi
    fi

    # ----------------------------------------------------------------------
    # 5. Update icon cache
    # ----------------------------------------------------------------------
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache "$TARGET_DIR" -f -q
        print_status "Icon cache updated."
    fi

    print_status "Adwaita-custom theme created successfully."
    return 0
}

# ============================================
# Main
# ============================================
main() {
    echo "=========================================="
    echo "Icon Theme Customization Script"
    echo "=========================================="
    echo ""
    echo "Include MoreWaita? If yes, all its mimetype icons will be copied"
    echo "into Adwaita-custom, but recolored icons (including the two generic"
    echo "script icons and explicit Adwaita-teal mimetypes) will be preserved."
    echo ""
    while true; do
        read -p "Include MoreWaita? (yes/no): " ans
        case "$ans" in
            yes|YES|y|Y) USE_MOREWAITA_APPS="yes"; break;;
            no|NO|n|N) USE_MOREWAITA_APPS="no"; break;;
            *) print_error "Please answer yes or no.";;
        esac
    done
    echo ""

    create_adwaita_custom "$USE_MOREWAITA_APPS" || exit 1

    echo ""
    echo "=========================================="
    print_status "Theme creation complete!"
    echo ""
    echo "Apply theme now?"
    echo "1) Yes"
    echo "2) No"
    while true; do
        read -p "Choice (1-2): " choice
        case $choice in
            1) gsettings set org.gnome.desktop.interface icon-theme "Adwaita-custom"
               print_status "Theme applied. Restart apps if needed."
               break;;
            2) print_status "You can apply later with: gsettings set org.gnome.desktop.interface icon-theme 'Adwaita-custom'"; break;;
            *) print_error "Invalid choice.";;
        esac
    done
}

# Check root
if [ "$EUID" -eq 0 ]; then
    print_error "Do not run as root."
    exit 1
fi

main
echo ""
print_status "Done. Theme location: $HOME/.local/share/icons/Adwaita-custom"
