module.exports = {
  apps : [{
    name: "tileserver",
    script: "runTileserver",
    exec_interpreter: "bash"
  }, {
    name: "backend-api",
    script: "/usr/src/backend-api/server.js",
    exec_interpreter: "/root/.nvm/versions/node/v12.14.1/bin/node"
  }]
}