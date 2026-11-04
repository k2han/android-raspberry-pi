#!/system/bin/sh

set -eu

config=${1:?Usage: apply_perf_profile.sh config.txt}
profile=${2:-$(getprop persist.tesla-android.perf_profile)}
profile=${profile:-default}

case "$profile" in
    default|performance) ;;
    *)
        echo "Unsupported performance profile: $profile" >&2
        exit 2
        ;;
esac

if [ ! -f "$config" ]; then
    echo "Boot configuration not found: $config" >&2
    exit 1
fi

tmp=$(mktemp "${config}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

cp -p "$config" "$tmp"
awk '
    $0 == "# tesla-android perf profile" {
        if (in_block) malformed = 1
        in_block = 1
        next
    }
    $0 == "# end tesla-android perf profile" {
        if (!in_block) malformed = 1
        in_block = 0
        next
    }
    !in_block { print }
    END {
        if (in_block || malformed) exit 2
    }
' "$config" > "$tmp"

if [ "$profile" = performance ]; then
    cat >> "$tmp" <<'EOF'
# tesla-android perf profile
arm_freq=2000
over_voltage=6
gpu_freq=750
force_turbo=0
# end tesla-android perf profile
EOF
fi

if ! cmp -s "$config" "$tmp"; then
    mv "$tmp" "$config"
fi
