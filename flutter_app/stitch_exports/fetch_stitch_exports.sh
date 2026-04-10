#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCREEN_DIR="${ROOT_DIR}/screens"
HTML_DIR="${ROOT_DIR}/html"

mkdir -p "${SCREEN_DIR}" "${HTML_DIR}"

curl -L "https://lh3.googleusercontent.com/aida/ADBb0uhWRFRfUcvUKoI9ZDpAo89Kl78B1Lg9O3uEYT5hC8HHsySmu3s8QYPQIysp3njbpD50Q3Uwhi88nRlUDcYUt8rCEzIT2obLyOJnhsSkXfVQdSFBzKeRxkg-D4g4dl4BQAdQVpk6L1t7yEPWshHnnSVf1zJJiocKc8zeViZzGI0DjNyHjCCmuTDdkhSs2En7O4oX3lvc3FNtFfO-X_sognfMZy0dPuWjL8R60nno7GJ20S-rABmObaywq8M" \
  -o "${SCREEN_DIR}/pipeline_settings.png"
curl -L "https://lh3.googleusercontent.com/aida/ADBb0uhJh7Hofd9-VXt456vy8IIhxU2YsKqpW91nWuizy0Kdwhe2_0rHXKhiHPdkROIp31Ji7lFzg8M1I0R5QE7vVAUl0HjHlX140PJLg9Ur-0D9h6-y6L3u3dV0czg7-9H1WZnuL1xtIjPrKziJcRf5FGS4IHwKkJzu6ULooQR3FEicosVhj-iV4pNeD0ip-zKyVgika-bqCxZlBti259SgNStovcnD-u8F_n7COHuOzG5lXncMg5IzLofPeg" \
  -o "${SCREEN_DIR}/batch_dashboard.png"
curl -L "https://lh3.googleusercontent.com/aida/ADBb0ujZ3LgaBwMuWDBVTQl9QBnd5_WCi7bvsLbm4RGBX_qhHejBSZ9spb0kLfOCaE4Pb7iRuR8yKm-D33isHF-hngLuBtLC1ZPwCOHlP-LO-0KczXa3csXafBIy_WccJDwuZyDDVWrXDHHtrf5COCFZZnov_kE3i9U9NCNZV5MZDZshTEiSRsnN14rGEMGvv9Vr58nib3Iuh69kS1bBZfuCOeTlHtIgFpOm-44pe0C2m-Tlvqnnh2DCgkKlEg" \
  -o "${SCREEN_DIR}/output_review_gallery.png"

curl -L "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzZiN2IyN2IyYmYxZTQyNTE4ZDJmMTdhZDVhYjA3ZTM5EgsSBxCm2Iny5AoYAZIBIwoKcHJvamVjdF9pZBIVQhMxODYyMDg4OTE2MTI2Njk1Mzc3&filename=&opi=89354086" \
  -o "${HTML_DIR}/pipeline_settings.html"
curl -L "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzgwZmY4NDAzMzAwZjQzN2Y5N2RmNTFhOTZmZmMwODY4EgsSBxCm2Iny5AoYAZIBIwoKcHJvamVjdF9pZBIVQhMxODYyMDg4OTE2MTI2Njk1Mzc3&filename=&opi=89354086" \
  -o "${HTML_DIR}/batch_dashboard.html"
curl -L "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzUyNWExMzM2YzYxNTQzYjhiNWY5MzIwNDZlNzBmMWIwEgsSBxCm2Iny5AoYAZIBIwoKcHJvamVjdF9pZBIVQhMxODYyMDg4OTE2MTI2Njk1Mzc3&filename=&opi=89354086" \
  -o "${HTML_DIR}/output_review_gallery.html"

echo "Downloaded Stitch exports to ${ROOT_DIR}"
