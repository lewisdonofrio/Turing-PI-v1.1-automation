TS=$(date +%Y%m%d-%H%M%S)
DEST="/home/builder/backups/node5-scripts-$TS"

mkdir -p "$DEST"

rsync -avh \
  --delete \
  builder@kubenode5.home.lab:/home/builder/scripts/ \
  "$DEST"/
