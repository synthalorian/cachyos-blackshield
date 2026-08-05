#!/bin/bash
# Verify FFI library loading for Open Synth desktop deployment
# Run this after build + deploy to confirm the .so loads correctly

echo "=== Open Synth FFI Library Verification ==="
echo ""

# Check deployed binary
BUNDLE_DIR="$HOME/.local/share/open_synth"
BINARY="$BUNDLE_DIR/open_synth"
SO_FILE="$BUNDLE_DIR/lib/libopenamp_dart_ffi.so"

echo "1. Checking deployed binary..."
if [ -f "$BINARY" ]; then
    echo "   ✓ Binary exists: $BINARY"
    echo "   ✓ Size: $(du -h "$BINARY" | cut -f1)"
    echo "   ✓ Modified: $(stat -c '%y' "$BINARY" | cut -d'.' -f1)"
else
    echo "   ✗ Binary NOT FOUND at $BINARY"
    exit 1
fi

echo ""
echo "2. Checking native library..."
if [ -f "$SO_FILE" ]; then
    echo "   ✓ .so exists: $SO_FILE"
    echo "   ✓ Size: $(du -h "$SO_FILE" | cut -f1)"
    echo "   ✓ Modified: $(stat -c '%y' "$SO_FILE" | cut -d'.' -f1)"
else
    echo "   ✗ .so NOT FOUND at $SO_FILE"
    echo "   Run: cp native/libopenamp_dart_ffi.so $BUNDLE_DIR/lib/"
    exit 1
fi

echo ""
echo "3. Checking library dependencies..."
ldd "$SO_FILE" 2>/dev/null | head -20

echo ""
echo "4. Testing library load..."
if python3 -c "
import ctypes
try:
    lib = ctypes.CDLL('$SO_FILE')
    print('   ✓ Library loads successfully')
except Exception as e:
    print(f'   ✗ Failed to load: {e}')
" 2>/dev/null; then
    :
else
    echo "   (python3 ctypes test skipped)"
fi

echo ""
echo "5. Checking _openLibrary() has Platform.resolvedExecutable path..."
OPENAMP_DART="/home/synth/projects/open-synth/lib/ffi/openamp_synth.dart"
if grep -q "Platform.resolvedExecutable" "$OPENAMP_DART" 2>/dev/null; then
    echo "   ✓ Platform.resolvedExecutable path is present"
else
    echo "   ✗ MISSING — _openLibrary() needs Platform.resolvedExecutable fix"
    echo "   See: references/ffi-library-path-resolution.md"
fi

echo ""
echo "=== Verification Complete ==="
