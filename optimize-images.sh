#!/bin/bash

# Image Optimization Script for 1earn Repository
# This script optimizes the largest images for better performance

set -e

echo "🚀 Starting image optimization for 1earn repository..."

# Create backup directory
BACKUP_DIR="./assets-backup-$(date +%Y%m%d-%H%M%S)"
echo "📦 Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Function to backup and optimize PNG files
optimize_large_pngs() {
    echo "🔍 Finding PNG files larger than 100KB..."
    
    # Find and list large PNG files
    large_pngs=$(find ./assets -name "*.png" -size +100k)
    count=$(echo "$large_pngs" | wc -l)
    
    if [ -z "$large_pngs" ]; then
        echo "✅ No PNG files larger than 100KB found"
        return
    fi
    
    echo "📊 Found $count large PNG files to optimize"
    
    total_size_before=0
    total_size_after=0
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Get original size
            size_before=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            total_size_before=$((total_size_before + size_before))
            
            # Create backup
            backup_file="$BACKUP_DIR/$(basename "$file")"
            cp "$file" "$backup_file"
            
            echo "🔧 Optimizing: $file ($(numfmt --to=iec $size_before))"
            
            # Try different optimization methods
            if command -v optipng >/dev/null 2>&1; then
                optipng -o2 -quiet "$file" || echo "⚠️  optipng failed for $file"
            fi
            
            if command -v pngquant >/dev/null 2>&1; then
                pngquant --quality=70-85 --ext .png --force "$file" || echo "⚠️  pngquant failed for $file"
            fi
            
            # Get new size
            size_after=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            total_size_after=$((total_size_after + size_after))
            
            savings=$((size_before - size_after))
            percentage=$(( (savings * 100) / size_before ))
            
            echo "✨ Saved: $(numfmt --to=iec $savings) ($percentage%)"
        fi
    done <<< "$large_pngs"
    
    total_savings=$((total_size_before - total_size_after))
    total_percentage=$(( (total_savings * 100) / total_size_before ))
    
    echo ""
    echo "📈 PNG Optimization Summary:"
    echo "   Before: $(numfmt --to=iec $total_size_before)"
    echo "   After:  $(numfmt --to=iec $total_size_after)"
    echo "   Saved:  $(numfmt --to=iec $total_savings) ($total_percentage%)"
}

# Function to optimize JPEG files
optimize_jpegs() {
    echo ""
    echo "🔍 Finding JPEG files..."
    
    jpegs=$(find ./assets -name "*.jpg" -o -name "*.jpeg")
    count=$(echo "$jpegs" | grep -c . || echo "0")
    
    if [ "$count" -eq 0 ]; then
        echo "✅ No JPEG files found"
        return
    fi
    
    echo "📊 Found $count JPEG files to optimize"
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            size_before=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            
            # Create backup
            backup_file="$BACKUP_DIR/$(basename "$file")"
            cp "$file" "$backup_file"
            
            echo "🔧 Optimizing: $file"
            
            if command -v jpegoptim >/dev/null 2>&1; then
                jpegoptim --max=85 --strip-all "$file" || echo "⚠️  jpegoptim failed for $file"
            fi
            
            size_after=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            savings=$((size_before - size_after))
            
            if [ "$size_before" -gt 0 ]; then
                percentage=$(( (savings * 100) / size_before ))
                echo "✨ Saved: $(numfmt --to=iec $savings) ($percentage%)"
            fi
        fi
    done <<< "$jpegs"
}

# Function to suggest WebP conversion
suggest_webp_conversion() {
    echo ""
    echo "💡 WebP Conversion Suggestions:"
    echo "   For even better compression, consider converting images to WebP format:"
    echo ""
    echo "   # Convert JPEGs to WebP (requires cwebp):"
    echo "   find ./assets -name '*.jpg' -exec cwebp -q 80 {} -o {}.webp \\;"
    echo ""
    echo "   # Convert PNGs to WebP (for photos, not graphics):"
    echo "   find ./assets -name '*.png' -path '*/photos/*' -exec cwebp -q 80 {} -o {}.webp \\;"
    echo ""
    echo "   WebP can provide 25-50% additional savings over optimized JPEG/PNG"
}

# Function to analyze and report on assets
analyze_assets() {
    echo ""
    echo "📊 Asset Analysis Report:"
    echo "========================="
    
    # Count files by type
    png_count=$(find ./assets -name "*.png" | wc -l)
    jpg_count=$(find ./assets -name "*.jpg" -o -name "*.jpeg" | wc -l)
    gif_count=$(find ./assets -name "*.gif" | wc -l)
    svg_count=$(find ./assets -name "*.svg" | wc -l)
    
    echo "📁 File counts:"
    echo "   PNG files: $png_count"
    echo "   JPEG files: $jpg_count"
    echo "   GIF files: $gif_count"
    echo "   SVG files: $svg_count"
    
    # Total sizes
    total_size=$(du -h ./assets | tail -1 | cut -f1)
    echo "   Total assets size: $total_size"
    
    # Largest files
    echo ""
    echo "🔝 Top 10 largest files:"
    find ./assets -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) -exec ls -lh {} \; | sort -k5 -hr | head -10 | awk '{print "   " $5 " - " $9}'
}

# Check for required tools
check_tools() {
    echo "🔍 Checking for optimization tools..."
    
    missing_tools=()
    
    if ! command -v optipng >/dev/null 2>&1; then
        missing_tools+=("optipng")
    fi
    
    if ! command -v pngquant >/dev/null 2>&1; then
        missing_tools+=("pngquant")
    fi
    
    if ! command -v jpegoptim >/dev/null 2>&1; then
        missing_tools+=("jpegoptim")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "⚠️  Missing optimization tools: ${missing_tools[*]}"
        echo "📦 Install them with:"
        echo "   Ubuntu/Debian: sudo apt install optipng pngquant jpegoptim"
        echo "   macOS: brew install optipng pngquant jpegoptim"
        echo "   Windows: choco install optipng pngquant jpegoptim"
        echo ""
        echo "🔄 Continuing with available tools..."
    else
        echo "✅ All optimization tools are available"
    fi
}

# Main execution
main() {
    echo "1earn Repository Image Optimizer"
    echo "================================"
    
    # Change to repository root if not already there
    if [ ! -d "./assets" ]; then
        echo "❌ Assets directory not found. Please run this script from the repository root."
        exit 1
    fi
    
    check_tools
    analyze_assets
    optimize_large_pngs
    optimize_jpegs
    suggest_webp_conversion
    
    echo ""
    echo "✅ Optimization complete!"
    echo "📦 Backup created at: $BACKUP_DIR"
    echo "🔄 Run 'git status' to see changes"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Review the optimized images"
    echo "   2. Test that the repository still works correctly"
    echo "   3. Commit the optimized images"
    echo "   4. Consider implementing WebP conversion for additional savings"
}

# Run only if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi