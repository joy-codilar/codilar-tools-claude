#!/usr/bin/env bash
# Detects the project stack(s) in a repo and prints a JSON profile.
# Usage: detect-stack.sh [project_dir]
# Pure bash + grep/find so it runs on macOS and Linux without extra tools.

root="${1:-.}"
cd "$root" 2>/dev/null || { echo '{"error":"project dir not found"}'; exit 1; }

PRUNE='-name node_modules -o -name vendor -o -name .git -o -name generated -o -name var -o -name pub -o -name dist -o -name build -o -name .next -o -name ios -o -name android'

has()   { grep -qE "$1" "$2" 2>/dev/null; }
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

components=()
add() { components+=("$1"); }

# ---------- Magento / Adobe Commerce ----------
for cj in $(find . -maxdepth 3 \( $PRUNE \) -prune -o -name composer.json -print 2>/dev/null); do
  dir="$(dirname "$cj")"
  if has '"magento/(product-(community|enterprise)-edition|magento-cloud-metapackage)"' "$cj" || [ -f "$dir/bin/magento" -a -d "$dir/app/etc" ]; then
    edition="open-source"
    has '"magento/(product-enterprise-edition|magento-cloud-metapackage)"' "$cj" && edition="adobe-commerce"
    version="$(grep -oE '"magento/product-(community|enterprise)-edition"[[:space:]]*:[[:space:]]*"[^"]+"' "$cj" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"

    hyva=false
    if has 'hyva-themes/magento2-(default-theme|theme-module)' "$cj" || has 'hyva-themes/magento2-(default-theme|theme-module)' "$dir/composer.lock"; then hyva=true; fi
    themes=""; luma_based=false
    for t in "$dir"/app/design/frontend/*/*; do
      [ -d "$t" ] || continue
      name="${t#"$dir"/app/design/frontend/}"
      parent="$(grep -oE '<parent>[^<]+</parent>' "$t/theme.xml" 2>/dev/null | sed -E 's#</?parent>##g')"
      if [ -d "$t/web/tailwind" ] || printf '%s' "$parent" | grep -qi 'hyva'; then hyva=true; kind="hyva"
      else kind="luma"; luma_based=true; fi
      themes="$themes{\"name\":\"$(json_escape "$name")\",\"parent\":\"$(json_escape "$parent")\",\"type\":\"$kind\"},"
    done
    themes="[${themes%,}]"
    frontend="none-custom"
    $luma_based && frontend="luma"
    $hyva && frontend="hyva"
    $hyva && $luma_based && frontend="hyva+luma"
    modules=$(ls -d "$dir"/app/code/*/* 2>/dev/null | wc -l | tr -d ' ')
    add "{\"type\":\"magento\",\"path\":\"$(json_escape "$dir")\",\"edition\":\"$edition\",\"version\":\"$(json_escape "$version")\",\"frontend\":\"$frontend\",\"themes\":$themes,\"customModules\":$modules}"
  fi
done

# ---------- Shopify theme / app ----------
for d in $(find . -maxdepth 3 \( $PRUNE \) -prune -o \( -name shopify.theme.toml -o -name settings_schema.json -o -name shopify.app.toml \) -print 2>/dev/null | xargs -n1 dirname 2>/dev/null | sort -u); do
  case "$d" in */config) d="$(dirname "$d")";; esac
  if [ -f "$d/shopify.app.toml" ]; then add "{\"type\":\"shopify\",\"subtype\":\"app\",\"path\":\"$(json_escape "$d")\"}"
  elif [ -f "$d/layout/theme.liquid" ] || [ -f "$d/shopify.theme.toml" ]; then add "{\"type\":\"shopify\",\"subtype\":\"theme\",\"path\":\"$(json_escape "$d")\"}"
  fi
done

# ---------- JS / TS projects ----------
backend_of() { # guess commerce backend used by a headless frontend dir
  local d="$1" m=0 s=0 a=0 files
  files="$(find "$d" -maxdepth 4 \( $PRUNE \) -prune -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.graphql' -o -name '*.gql' -o -name '.env*' -o -name 'package.json' \) -print 2>/dev/null | head -3000)"
  [ -z "$files" ] && { echo "unknown"; return; }
  m=$(printf '%s\n' "$files" | xargs grep -lE 'addProductsToCart|createEmptyCart|customerCart|generateCustomerToken|urlResolver|MAGENTO_|magento' 2>/dev/null | wc -l)
  s=$(printf '%s\n' "$files" | xargs grep -lE '@shopify/(storefront-api-client|hydrogen-react|hydrogen)|myshopify\.com|SHOPIFY_STOREFRONT|Storefront-Access-Token' 2>/dev/null | wc -l)
  a=$(printf '%s\n' "$files" | xargs grep -liE '@akinon/|akinon' 2>/dev/null | wc -l)
  if [ "$m" -eq 0 ] && [ "$s" -eq 0 ] && [ "$a" -eq 0 ]; then echo "unknown"
  elif [ "$m" -ge "$s" ] && [ "$m" -ge "$a" ]; then echo "magento"
  elif [ "$s" -ge "$a" ]; then echo "shopify"
  else echo "akinon"; fi
}

has_nest=false
for pj in $(find . -maxdepth 3 \( $PRUNE \) -prune -o -name package.json -print 2>/dev/null); do
  d="$(dirname "$pj")"
  if has '"@nestjs/core"' "$pj"; then has_nest=true; add "{\"type\":\"nestjs\",\"path\":\"$(json_escape "$d")\"}"; fi
done

for pj in $(find . -maxdepth 3 \( $PRUNE \) -prune -o -name package.json -print 2>/dev/null); do
  d="$(dirname "$pj")"
  if has '"@akinon/next"' "$pj" || [ -f "$d/akinon.json" ]; then
    add "{\"type\":\"akinon\",\"subtype\":\"projectzero-storefront\",\"path\":\"$(json_escape "$d")\"}"
  elif has '"@shopify/hydrogen"' "$pj"; then
    add "{\"type\":\"shopify\",\"subtype\":\"hydrogen\",\"path\":\"$(json_escape "$d")\"}"
  elif has '"react-native"' "$pj"; then
    b="$(backend_of "$d")"; $has_nest && [ "$b" = "unknown" ] && b="nestjs"
    add "{\"type\":\"react-native\",\"expo\":$(has '"expo"' "$pj" && echo true || echo false),\"backend\":\"$b\",\"path\":\"$(json_escape "$d")\"}"
  elif has '"next"[[:space:]]*:' "$pj"; then
    b="$(backend_of "$d")"; $has_nest && [ "$b" = "unknown" ] && b="nestjs"
    add "{\"type\":\"nextjs\",\"backend\":\"$b\",\"path\":\"$(json_escape "$d")\"}"
  fi
done
# Akinon backend extension repos usually carry akinon.json without a package.json
for f in $(find . -maxdepth 2 \( $PRUNE \) -prune -o -name akinon.json -print 2>/dev/null); do
  d="$(dirname "$f")"; [ -f "$d/package.json" ] && continue
  add "{\"type\":\"akinon\",\"subtype\":\"extension\",\"path\":\"$(json_escape "$d")\"}"
done

# ---------- Suggested profile (maps to the 8 Codilar project types) ----------
all="$(printf '%s\n' "${components[@]}")"
profile="unknown"
if   printf '%s' "$all" | grep -q '"type":"nestjs"' && printf '%s' "$all" | grep -q '"type":"nextjs"'; then profile="custom-nestjs-nextjs"
elif printf '%s' "$all" | grep -q '"type":"react-native"'; then profile="react-native-$(printf '%s' "$all" | grep '"type":"react-native"' | head -1 | sed -E 's/.*"backend":"([^"]+)".*/\1/')"
elif printf '%s' "$all" | grep -q '"type":"nextjs"'; then profile="nextjs-$(printf '%s' "$all" | grep '"type":"nextjs"' | head -1 | sed -E 's/.*"backend":"([^"]+)".*/\1/')"
elif printf '%s' "$all" | grep -q '"type":"akinon"'; then profile="akinon"
elif printf '%s' "$all" | grep -q '"type":"shopify"'; then profile="shopify"
elif printf '%s' "$all" | grep -q '"frontend":"hyva'; then profile="magento-hyva"
elif printf '%s' "$all" | grep -q '"frontend":"luma"'; then profile="magento-luma"
elif printf '%s' "$all" | grep -q '"type":"magento"'; then profile="magento"
elif printf '%s' "$all" | grep -q '"type":"nestjs"'; then profile="custom-nestjs-nextjs"
fi

# Test tooling hints
tools=""
for t in vendor/bin/phpunit vendor/bin/phpcs vendor/bin/phpstan vendor/bin/mftf; do [ -x "$t" ] && tools="$tools\"$t\","; done
pjs="$(find . -maxdepth 3 \( $PRUNE \) -prune -o -name package.json -print 2>/dev/null)"
for t in jest vitest playwright cypress eslint detox; do [ -n "$pjs" ] && printf '%s\n' "$pjs" | xargs grep -qsE "\"$t\"" 2>/dev/null && tools="$tools\"$t\","; done

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
remote="$(git remote get-url origin 2>/dev/null)"
comp="$(IFS=,; echo "${components[*]}")"
printf '{"suggestedProfile":"%s","components":[%s],"testTools":[%s],"git":{"currentBranch":"%s","origin":"%s"}}\n' \
  "$profile" "$comp" "${tools%,}" "$(json_escape "$branch")" "$(json_escape "$remote")"
