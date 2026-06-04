# mongo-deploy

Docker Compose setup for a MongoDB 8 single-node replica set with:

- Local host access on loopback only (`127.0.0.1`)
- Cloudflare Tunnel connector (`cloudflared`) for remote access
- Auth-enabled Mongo bootstrap via a custom init script

## Services

- `mongo`:
  - MongoDB 8
  - Replica set: `rs0`
  - Auth enabled
  - Host bind: `127.0.0.1:${MONGO_RS_PORT}:27017`
- `cloudflared`:
  - Runs your Cloudflare Tunnel token
  - Reaches Mongo over internal Docker network

## Requirements

- Docker + Docker Compose plugin
- Cloudflare Tunnel already created
- Cloudflare route for `mongo-db.eodeluga.com` set to:
  - `tcp://mongo:27017`

## Environment Variables

Create `.env` for `docker-compose.yml` and `.env.dev` for `docker-compose.dev.yml` (both are gitignored).

Default compose example:

```dotenv
CLOUDFLARE_TOKEN=<your-cloudflare-tunnel-token>
MONGO_RS_HOST=mongo
MONGO_RS_PORT=27019
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=<strong-password>
```

Dev compose example:

```dotenv
MONGO_RS_HOST=mongo
MONGO_RS_PORT=27017
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=<strong-password>
```

For `docker-compose.dev.yml`, `MONGO_PORT` controls the host-published port and defaults to `27017`. Keep `MONGO_RS_PORT=27017` so the replica set advertises the same port Mongo actually listens on inside Docker.

## Start

Default compose:

```bash
docker compose up -d
```

Dev compose:

```bash
docker compose --env-file .env.dev -f docker-compose.dev.yml up -d
```

Check status:

Default compose:

```bash
docker compose ps
docker logs --tail 100 mongo-db
```

Dev compose:

```bash
docker compose -f docker-compose.dev.yml ps
docker logs --tail 100 mongo-db
```

## Connect (Local Machine)

Default compose exposes Mongo locally on `127.0.0.1:${MONGO_RS_PORT}`.

Mongo Compass URI:

```text
mongodb://<username>:<password>@127.0.0.1:${MONGO_RS_PORT}/?authSource=admin&directConnection=true
```

For dev compose, connect to `127.0.0.1:${MONGO_PORT:-27017}` instead.

## Connect Through Cloudflare Tunnel

On your client machine, start a local forwarder:

```text
cloudflared access tcp --hostname <your-cloudflare-tunnel-host> --url 127.0.0.1:37017
```

Then connect Compass to:

```text
mongodb://<username>:<password>@127.0.0.1:37017/?authSource=admin&directConnection=true
```

## Notes

- `MONGO_RS_PORT` is the host-published port only.
- Mongo inside Docker still listens on `27017`.
- `MONGO_PORT` only affects `docker-compose.dev.yml`.
- If you change `.env` or `.env.dev`, recreate the relevant containers:

```bash
docker compose up -d --force-recreate mongo cloudflared
```
