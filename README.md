# mongo-deploy

Docker Compose setup for a MongoDB 8 single-node replica set with:

* Local host access on loopback only (`127.0.0.1`)
* Cloudflare Tunnel connector (`cloudflared`)
* Secure remote access via **Cloudflare WARP + private network routing**
* Auth-enabled Mongo bootstrap via a custom init script

## Services

### `mongo`

* MongoDB 8
* Replica set: `rs0`
* Auth enabled
* Host bind: `127.0.0.1:${MONGO_RS_PORT}:27017`
* Internal Docker network address used for WARP access

### `cloudflared`

* Runs your Cloudflare Tunnel connector
* Advertises the Docker network to Cloudflare Zero Trust
* Enables WARP clients to reach Mongo through private routing

## Requirements

* Docker + Docker Compose plugin
* Cloudflare Tunnel already created
* Cloudflare Zero Trust configured with a **private network route**

Required route:

```
172.22.0.0/16
```

This should point to your Mongo tunnel connector.

This advertises the Docker network to WARP clients.

## Environment Variables

Create `.env` (already gitignored):

```dotenv
CLOUDFLARE_TOKEN=<your-cloudflare-tunnel-token>
MONGO_RS_HOST=mongo
MONGO_RS_PORT=27019
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=<strong-password>
```

## Start

```bash
docker compose up -d
```

Check status:

```bash
docker compose ps
docker logs --tail 100 mongo-db
```

## Connect (Local Machine)

Mongo is exposed locally on loopback only.

Mongo Compass URI:

```text
mongodb://<username>:<password>@127.0.0.1:27019/?authSource=admin&directConnection=true
```

Replace `27019` if you changed `MONGO_RS_PORT`.

## Connect Through Cloudflare WARP

[Install and connect the Cloudflare WARP client](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/download-warp/) on your local machine.

Once connected, your client becomes part of the private Zero Trust network.

Mongo can then be accessed using the container's internal IP:

```text
mongodb://<username>:<password>@172.22.0.10:27017/?authSource=admin&directConnection=true
```

Example connectivity test:

```bash
nc -4 -vz 172.22.0.10 27017
```

If this succeeds, WARP routing is functioning correctly.

## Optional: Friendly Hostname

If you prefer not to use the IP address, create a DNS override inside Zero Trust:

```
Traffic policies
→ DNS
→ Override
```

Example rule:

```
DNS Query: mongo-db.internal.eodeluga.com
Action: Override
Override IP: 172.22.0.10
```

Then you can connect using:

```text
mongodb://<username>:<password>@mongo-db.internal.eodeluga.com:27017/?authSource=admin&directConnection=true
```

This hostname resolution happens **inside the WARP network only** and does not require any public DNS records.

## Notes

* `MONGO_RS_PORT` is the host-published port only.
* Mongo inside Docker always listens on `27017`.
* Remote access uses the internal Docker network (`172.22.0.0/16`) via WARP.
* No `cloudflared access tcp` proxy is required when using WARP private network routing.

If you change `.env`, recreate containers:

```bash
docker compose up -d --force-recreate mongo cloudflared
```
