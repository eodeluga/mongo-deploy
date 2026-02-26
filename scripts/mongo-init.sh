#!/usr/bin/env bash
set -euo pipefail

# required envs
: "${MONGO_INITDB_ROOT_USERNAME:?missing}"
: "${MONGO_INITDB_ROOT_PASSWORD:?missing}"

KEYFILE="/data/configdb/keyfile"
MARKER="/data/configdb/replica.initialised"
# Use service name by default, but allow override
MONGO_RS_HOST="${MONGO_RS_HOST:-mongo}"
MONGO_RS_PORT="${MONGO_RS_PORT:-27017}"

# Keyfile must exist and be 0400 before any auth start
if [[ ! -f "$KEYFILE" ]]; then
  echo "🔑 Generating keyFile at $KEYFILE"
  umask 077
  openssl rand -base64 756 > "$KEYFILE"
  chown 999:999 "$KEYFILE"
  chmod 400 "$KEYFILE"
else
  chmod 400 "$KEYFILE" || true
fi

# Fast path: already bootstrapped → start with auth and exit script
if [[ -f "$MARKER" ]]; then
  echo "✅ Detected previous initialisation, starting mongod with auth"
  exec mongod --replSet rs0 --auth --keyFile "$KEYFILE" --bind_ip_all
fi

# Start mongod with replSet + auth in background
echo "🚀 Bootstrap start (no auth, localhost exception)"
mongod --replSet rs0 --keyFile "$KEYFILE" --bind_ip_all &
MONGO_PID=$!

# Wait until mongod answers pings
until mongosh --quiet --eval 'db.adminCommand({ ping: 1 }).ok' >/dev/null 2>&1; do
  echo "⏳ Waiting for mongod..."
  sleep 2
done

# Create replica set
echo "⚙️ Initiating replica set"
mongosh --quiet --eval "
  try {
    rs.initiate({ _id: 'rs0', members: [{ _id: 0, host: '${MONGO_RS_HOST}:${MONGO_RS_PORT}' }] })
    print('✅ rs.initiate called')
  } catch (e) { print('ℹ️ rs.initiate note: ' + e) }
"

# Wait until replica primary
until mongosh --quiet --eval '
  const h = db.hello()
  quit((h.ok === 1 && (h.isWritablePrimary || h.secondary)) ? 0 : 1)
' >/dev/null 2>&1; do
  echo "⏳ Waiting for replica to become PRIMARY..."
  sleep 2
done

# Create root user if missing
echo "🔐 Ensuring admin user exists..."
mongosh admin --quiet <<'EOF'
try {
  db.createUser({
    user: process.env.MONGO_INITDB_ROOT_USERNAME,
    pwd:  process.env.MONGO_INITDB_ROOT_PASSWORD,
    roles: [{ role: "root", db: "admin" }]
  })
  print("✅ Admin user created")
} catch (e) {
  if (!/already exists/i.test(String(e))) { print("⚠️ createUser note: " + e) }
}
EOF

# All tasks requiring unauthenticated access completed so shutdown
echo "☠️  Shutting down unauthenticated mongod process"
mongosh admin --quiet --eval 'db.shutdownServer()' >/dev/null 2>&1 || true
wait "$MONGO_PID" || true
sleep 1

# Mark as bootstrapped so future restarts go straight to auth mode
touch "$MARKER"

# Restart server
exec mongod \
  --replSet rs0 \
  --auth \
  --keyFile "$KEYFILE" \
  --bind_ip_all
