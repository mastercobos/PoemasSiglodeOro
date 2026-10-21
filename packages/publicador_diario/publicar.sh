#!/usr/bin/env bash
# Posts one app's poems of the day to its Tumblr blog.
#
#   publicar.sh es        # both poems
#   publicar.sh fr 1      # only the first (e.g. in the morning)
#   publicar.sh en 2      # only the second (e.g. in the evening)
#   DIAS=30 publicar.sh es  # schedule the next 30 days on Tumblr instead
#
# Scheduled posts go out at each app's GuionPublicacion.horas in $TZ,
# Europe/Madrid unless the app's .env sets another. Tumblr caps a blog at
# 300 queued posts and limits uploads per day, so a month at a time is safe;
# a run cut short can be repeated, it carries on where it stopped.
#
# The blog's credentials are read from $POEMARIO_BOT/<app>.env (default
# ~/.config/poemario-bot), one VAR=value per line, mode 600:
#
#   TUMBLR_BLOG=poemario-siglodeoro
#   TUMBLR_CONSUMER_KEY=...
#   TUMBLR_CONSUMER_SECRET=...
#   TUMBLR_TOKEN=...
#   TUMBLR_TOKEN_SECRET=...
#
# What has been posted is recorded in $POEMARIO_BOT/estado, so a failed run
# can be repeated without posting anything twice. Example crontab (the
# server's clock decides what "today" is, so set its time zone):
#
#   TZ=Europe/Madrid
#   0 9  * * * /ruta/al/repo/packages/publicador_diario/publicar.sh es 1
#   0 20 * * * /ruta/al/repo/packages/publicador_diario/publicar.sh es 2
set -euo pipefail

app=${1:?Uso: publicar.sh <es|en|fr> [1|2]}
cual=${2:-}
config=${POEMARIO_BOT:-$HOME/.config/poemario-bot}
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ -f "$config/$app.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$config/$app.env"
  set +a
else
  echo "Sin $config/$app.env: solo se simula (build/publicaciones)." >&2
fi

export TZ=${TZ:-Europe/Madrid}
cd "$repo/apps/$app"
CUAL=$cual ESTADO="$config/estado" flutter test --no-pub publicacion/
