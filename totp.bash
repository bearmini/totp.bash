#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s extglob

if ! command -v openssl >/dev/null 2>&1; then
  echo "'openssl' command is required to generate TOTP codes." 1>&2
  exit 0
fi

if ! command -v base32 >/dev/null 2>&1; then
  echo "'base32' command is required to generate TOTP codes." 1>&2
  exit 0
fi

color_red=$'\e[0;31m'
color_green=$'\e[0;32m'
color_reset=$'\e[0m'
totp_algorithm="${totp_algorithm:-SHA1}"
totp_digits="${totp_digits:-6}"
totp_period="${totp_period:-30}"

test_compare() {
  local actual=$1
  local expected=$2
  if [ "$actual" != "$expected" ]; then
    echo -e "${color_red}FAIL:${color_reset}"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    exit 1
  fi
}

generate_totp_uri() {
  local issuer=$1
  local account=$2
  local secret_plain_text=$3
  local encoded_secret
  encoded_secret="$( echo "$secret_plain_text" | base32 )"
  echo "otpauth://totp/${issuer}:${account}?secret=${encoded_secret}&issuer=${issuer}&algorithm=${totp_algorithm}&digits=${totp_digits}&period=${totp_period}"
}

test_generate_totp_uri() {
  local issuer="TestIssuer"
  local account="TestAccountName"
  local secret_plain_text="P@ssw0rd"
  local expected="otpauth://totp/TestIssuer:TestAccountName?secret=KBAHG43XGBZGICQ=&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30"
  local actual
  actual="$( generate_totp_uri "$issuer" "$account" "$secret_plain_text" )"
  test_compare "$actual" "$expected"
}

extract_secret_parameter_from_totp_uri() {
  local totp_uri=$1
  [[ "$totp_uri" =~ secret=([A-Z0-9=]*) ]] && echo "${BASH_REMATCH[1]}"
}

test_extract_secret_parameter_from_totp_uri() {
  local totp_uri="otpauth://totp/TestIssuer:TestAccountName:WithColon?secret=KBAHG43XGBZGICQ=&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30"
  local expected="KBAHG43XGBZGICQ="
  local actual
  actual="$( extract_secret_parameter_from_totp_uri "$totp_uri" )"
  test_compare "$actual" "$expected"
}

extract_secret_plain_text_from_totp_uri() {
  local totp_uri=$1
  extract_secret_parameter_from_totp_uri "$totp_uri" | base32 -d
}

test_extract_secret_plain_text_from_totp_uri() {
  local totp_uri="otpauth://totp/TestIssuer:TestAccountName:WithColon?secret=KBAHG43XGBZGICQ=&issuer=TestIssuer&algorithm=SHA1&digits=6&period=30"
  local expected="P@ssw0rd"
  local actual
  actual="$( extract_secret_plain_text_from_totp_uri "$totp_uri" )"
  test_compare "$actual" "$expected"
}

hmac() {
  local k=$1 # secret key
  local c=$2 # counter

  case "$totp_algorithm" in
    "SHA1")
      result="$( echo -n "$( printf %016X "$c" )" | xxd -r -p | openssl dgst -sha1 -mac HMAC -macopt "key:$k" )"
      echo "${result##*+( )}"
      ;;
    *)
      echo "HMAC algorithm $totp_algorithm is not supported" 2>&1
      exit 1
      ;;
  esac
}

test_hmac() {
  local k
  local c
  local expected
  local actual

  k="P@ssw0rd"
  c="0"
  expected="c3a33df250c0b6d2ee6b3b7dab5e2a28d9c2390c"
  actual=$( hmac "$k" "$c" )
  test_compare "$actual" "$expected"

  k="P@ssw0rd"
  c="123456"
  expected="9f589f6fbcee7365e20429fbe9f6943df914702b"
  actual=$( hmac "$k" "$c" )
  test_compare "$actual" "$expected"
}

lsb_4bits() {
  local mac=$1
  case "$totp_algorithm" in
    "SHA1")
      echo "${mac:39}"
      ;;
    *)
      echo "HMAC algorithm $totp_algorithm is not supported" 2>&1
      exit 1
      ;;
  esac
}

test_lsb_4bits() {
  local mac="c411b2c6e83a924b544742df694df58cefc9ba2d"
  local expected="d"
  local actual
  actual="$( lsb_4bits "$mac" )"
  test_compare "$actual" "$expected"

  local mac="111111111122222222223333333333444444444f"
  local expected="f"
  local actual
  actual="$( lsb_4bits "$mac" )"
  test_compare "$actual" "$expected"
}

extract31() {
  local mac=$1
  local offset=$2
  local word="0x${mac:$(( offset * 2 )):8}"
  echo "$(( word & 0x7fffffff ))"
}

test_extract31() {
  local mac="0123456789abcdef0123456789abcdef01234567"
  local offset
  local expected
  local actual

  offset=0
  expected="$( printf "%d" 0x01234567 )"
  actual="$( extract31 "$mac" "$offset" )"
  test_compare "$actual" "$expected"

  offset=1
  expected="$( printf "%d" 0x23456789 )"
  actual="$( extract31 "$mac" "$offset" )"
  test_compare "$actual" "$expected"

  offset=5
  expected="$( printf "%d" 0x2bcdef01 )"
  actual="$( extract31 "$mac" "$offset" )"
  test_compare "$actual" "$expected"

  offset=10
  expected="$( printf "%d" 0x456789ab )"
  actual="$( extract31 "$mac" "$offset" )"
  test_compare "$actual" "$expected"
}

truncate() {
  local mac=$1
  local offset
  offset="$( printf %d "0x$( lsb_4bits "$mac" )" )"
  extract31 "$mac" "$offset"
}

test_truncate() {
  local mac
  local expected
  local actual

  mac="1f8698690e02ca16618550ef7f19da8e945b555a"
  expected="$( printf %d 0x50ef7f19 )"
  actual="$( truncate "$mac" )"
  test_compare "$actual" "$expected"
}

get_mod_base() {
  case "$totp_digits" in
    "6")
      echo "1000000"
      ;;
    "7")
      echo "10000000"
      ;;
    "8")
      echo "100000000"
      ;;
    *)
      echo "unsupported totp digits: $totp_digits" 1>&2
      exit 1
      ;;
  esac
}

calculate_hotp_value() {
  # https://en.wikipedia.org/wiki/HMAC-based_one-time_password
  local k=$1 # secret key
  local c=$2 # counter

  local h
  h="$( truncate "$( hmac "$k" "$c" )" )"
  local mod_base
  mod_base="$( get_mod_base )"
  echo "$(( h % mod_base ))"
}

test_calculate_hotp_value() {
  local k="P@ssw0rd"
  local c
  local expected
  local actual

  c=0
  expected="591464"
  actual="$( calculate_hotp_value "$k" "$c" )"
  test_compare "$actual" "$expected"

  c=1
  expected="115908"
  actual="$( calculate_hotp_value "$k" "$c" )"
  test_compare "$actual" "$expected"

  c=2
  expected="153515"
  actual="$( calculate_hotp_value "$k" "$c" )"
  test_compare "$actual" "$expected"
}

calculate_totp() {
  local password=$1
  local t
  t="$( date +%s )"

  local ct
  ct=$(( t / totp_period ))

  calculate_hotp_value "$password" "$ct"
}

test_all() {
  test_extract_secret_parameter_from_totp_uri
  test_extract_secret_plain_text_from_totp_uri
  test_hmac
  test_lsb_4bits
  test_extract31
  test_truncate
  test_calculate_hotp_value
}

# for testing each function
if [ -n "${1:-}" ]; then
  fn="$1"
  shift
  "$fn" "$@"

  if [[ "$fn" == "test_"* ]]; then
    echo -e "${color_green}OK${color_reset}"
  fi
fi
