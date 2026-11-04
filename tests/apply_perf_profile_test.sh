#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
helper="$root/aosptree/vendor/devices-community/gd_rpi4/boot/apply_perf_profile.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

config="$tmp/config.txt"
original="$tmp/original.txt"
cat > "$config" <<'EOF'
dtparam=audio=on
[all]
arm_boost=1
EOF
cp "$config" "$original"

sh "$helper" "$config" performance
for setting in arm_freq=2000 over_voltage=6 gpu_freq=750 force_turbo=0; do
    grep -qx "$setting" "$config"
done
[ "$(grep -c '^# tesla-android perf profile$' "$config")" -eq 1 ]

cp "$config" "$tmp/performance.txt"
sh "$helper" "$config" performance
cmp "$config" "$tmp/performance.txt"

sh "$helper" "$config" default
cmp "$config" "$original"

if sh "$helper" "$config" invalid; then
    echo "Invalid profile unexpectedly succeeded" >&2
    exit 1
fi
cmp "$config" "$original"

cat > "$tmp/getprop" <<'EOF'
#!/bin/sh
printf '%s\n' default
EOF
chmod +x "$tmp/getprop"
PATH="$tmp:$PATH" sh "$helper" "$config"
cmp "$config" "$original"

cat > "$config" <<'EOF'
dtparam=audio=on
# tesla-android perf profile
arm_freq=2000
EOF
cp "$config" "$original"
if sh "$helper" "$config" default; then
    echo "Malformed profile block unexpectedly succeeded" >&2
    exit 1
fi
cmp "$config" "$original"
