# Tileserver-gl with Varnish Cache

For ex.:

```
.
┗ 📂 tileserver
  ┗ 📜 docker-compose.yml
  ┗ 📂 data
    ┗ 📜 config.json
    ┗ 📜 style.json
    ┗ 📜 myMbtiles1.mbtiles
    ┗ 📜 myMbtiles2.mbtiles
```


## docker-compose.yml

```yaml
version: '3.7'
services: 
  tileserver:
    build: .
    container_name: tileserver
    ports: 
      - 80:8080 # tileserver only likes to be exposed at standard port: 80/443
      # - 3000:3000 never expose this port on the internet
    volumes: 
      - ./data:/data
    tmpfs: 
      - /usr/local/var/varnish:exec
    environment: 
      # how long things should be cache; https://varnish-cache.org/docs/6.3/reference/vcl.html#durations
      - CACHE_TTL=1d
```

## Basic [config.json](https://tileserver.readthedocs.io/en/latest/config.html)

```json
{
  "data": { "snow": { "mbtiles": "snow.mbtiles" } },
  "styles": { "snow": { "style": "snowStyle.json" } }
}
```

## Basic [style.json](https://docs.mapbox.com/mapbox-gl-js/style-spec/root/)

```json
{
  "version": 8,
  "name": "basic",
  "id": "basic",
  "sources": {
    "snow": {
      "url": "mbtiles://snow.mbtiles",
      "type": "vector"
    }
  },
  "layers": [
    {
      "id": "snow",
      "type": "fill",
      "source": "snow",
      "source-layer": "snow",
      "paint": {
        "fill-color": "#C69214",
        "fill-opacity": 0.5,
        "fill-outline-color": "rgba(0, 0, 0, 1)"
      }
    }
  ]
}
```

## Backend API
On port 3000 a REST API is exposed to do actions on the tileserver and cache. It should only be used in docker internal networks and never be exposed to the internet. If the container name is tileserver, it can be accessed by other containers in the same docker network with: `http://tileserver:3000`

* **GET** /
  * to test if a connection can be established to the backend api
* **POST** /reload
  * Restarts the tileserver and purges the whole cache. Should be called if the .mbtiles files have changed.
