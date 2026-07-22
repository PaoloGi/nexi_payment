#!/bin/bash
#
# Downloads the Nexi iOS SDKs into ios/Frameworks/ at `pod install` time.
#
# The binaries are Nexi's, not ours: we fetch them from Nexi's own release
# repository rather than redistributing them, which is what Nexi's official
# Nexi_XPay podspec does too. Every archive is pinned by SHA-256.
#
# Nexi publishes device and simulator builds as separate archives for XPaySDK
# and ThreeDS_SDK, so those two are merged into an xcframework here. Without
# the simulator slice `flutter build ios --simulator` fails with
# "No such module 'XPaySDK'".

set -euo pipefail

readonly BASE_XPAY="https://github.com/NexiPayments/sdk-ios/raw/master"
readonly BASE_NPG="https://github.com/NexiPayments/sdk-ios-npg/raw/main"

readonly XPAY_VERSION="1.5.1"
readonly NPG_VERSION="1.1.0"

readonly SHA_XPAY_DEVICE="ef1f3b0251a0ee6d86eb5621b29fe422d08e9fafa17353b9823835f26e5c26fc"
readonly SHA_XPAY_SIM="e17b4185f2d3978e117e4d401ba03285c69f38882a5ee39e7609d31a37c4a9cd"
readonly SHA_THREEDS_DEVICE="4ac70aa32451e45e5a10422c82ccd7304d26bbf5d1ab46af698ff499b4e6e140"
readonly SHA_THREEDS_SIM="5ad2f9325a969621b51c42cc65ba1c892b2fea2c3d0c8d16e028da094bb95d61"
readonly SHA_NPG="95696265b187c9a077ce9b7beb2c7d231b13fb28f81006bf053aef0fb6a864ab"

cd "$(dirname "$0")/.."
readonly FRAMEWORKS_DIR="$PWD/Frameworks"
# Bump when the pinned versions change so existing checkouts refetch.
readonly STAMP="$FRAMEWORKS_DIR/.fetched-xpay${XPAY_VERSION}-npg${NPG_VERSION}"

if [[ -f "$STAMP" ]]; then
  exit 0
fi

readonly WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# download <url> <destination> <expected sha256>
download() {
  local url="$1" dest="$2" expected="$3" actual
  echo "nexi_payment: fetching $(basename "$url")"
  curl --fail --silent --show-error --location --retry 3 --output "$dest" "$url"
  actual="$(shasum -a 256 "$dest" | cut -d' ' -f1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "nexi_payment: checksum mismatch for $url" >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    exit 1
  fi
}

# Nexi's archives contain a __MACOSX/ sibling; ignore it when locating results.
find_bundle() {
  find "$1" -maxdepth 2 -name "$2" -not -path '*__MACOSX*' | head -1
}

# merge_xcframework <name> <device zip> <simulator zip>
merge_xcframework() {
  local name="$1" device_zip="$2" sim_zip="$3"
  local extract_dir="$WORK_DIR/$name"
  mkdir -p "$extract_dir/device" "$extract_dir/sim"
  unzip -qo "$device_zip" -d "$extract_dir/device"
  unzip -qo "$sim_zip" -d "$extract_dir/sim"

  # XPaySDK ships its device build as an xcframework, ThreeDS_SDK as a plain
  # framework, so accept either shape.
  local device_xc device_fw sim_fw
  device_xc="$(find_bundle "$extract_dir/device" '*.xcframework')"
  if [[ -n "$device_xc" ]]; then
    device_fw="$(find "$device_xc" -maxdepth 2 -name '*.framework' | head -1)"
  else
    device_fw="$(find_bundle "$extract_dir/device" '*.framework')"
  fi
  sim_fw="$(find_bundle "$extract_dir/sim" '*.framework')"

  if [[ -z "$device_fw" || -z "$sim_fw" ]]; then
    echo "nexi_payment: could not locate $name framework in Nexi's archive" >&2
    exit 1
  fi

  # xcodebuild requires each framework directory to carry the module name.
  mkdir -p "$extract_dir/staged/device" "$extract_dir/staged/sim"
  cp -R "$device_fw" "$extract_dir/staged/device/$name.framework"
  cp -R "$sim_fw" "$extract_dir/staged/sim/$name.framework"

  xcodebuild -create-xcframework \
    -framework "$extract_dir/staged/device/$name.framework" \
    -framework "$extract_dir/staged/sim/$name.framework" \
    -output "$FRAMEWORKS_DIR/$name.xcframework" >/dev/null
}

rm -rf "$FRAMEWORKS_DIR"
mkdir -p "$FRAMEWORKS_DIR"

download "$BASE_XPAY/XPaySDK-v$XPAY_VERSION.xcframework.zip" \
  "$WORK_DIR/xpay-device.zip" "$SHA_XPAY_DEVICE"
download "$BASE_XPAY/XPaySDK-v$XPAY_VERSION-simulators.framework.zip" \
  "$WORK_DIR/xpay-sim.zip" "$SHA_XPAY_SIM"
merge_xcframework "XPaySDK" "$WORK_DIR/xpay-device.zip" "$WORK_DIR/xpay-sim.zip"

# XPaySDK imports ThreeDS_SDK, which Nexi distributes separately.
download "$BASE_XPAY/ThreeDS_SDK.framework.zip" \
  "$WORK_DIR/threeds-device.zip" "$SHA_THREEDS_DEVICE"
download "$BASE_XPAY/ThreeDS_SDK-simulators.framework.zip" \
  "$WORK_DIR/threeds-sim.zip" "$SHA_THREEDS_SIM"
merge_xcframework "ThreeDS_SDK" "$WORK_DIR/threeds-device.zip" "$WORK_DIR/threeds-sim.zip"

# NPG already ships one xcframework carrying both slices.
download "$BASE_NPG/ios-xpay-v$NPG_VERSION.zip" "$WORK_DIR/npg.zip" "$SHA_NPG"
unzip -qo "$WORK_DIR/npg.zip" -d "$WORK_DIR/npg"
cp -R "$(find_bundle "$WORK_DIR/npg" '*.xcframework')" "$FRAMEWORKS_DIR/NPGSDK.xcframework"

# Swift ABI descriptors are only used by ABI-diffing tools and are ~28 MB.
find "$FRAMEWORKS_DIR" -name '*.abi.json' -delete

touch "$STAMP"
echo "nexi_payment: frameworks ready in ios/Frameworks"
