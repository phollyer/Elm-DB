const ElmJsStore = {
  dbToElm: {},
  conns: {},
  middleWare: {},
  plugins: {},
  workerPath: "./jsstore.worker.min.js",
  response: {
    Clear: "Cleared",
    Count: "Counted",
    Drop: "Dropped",
    Get: "Get",
    GetDbList: "GotDbList",
    Insert: "Inserted",
    Interesect: "Intersect",
    Remove: "Removed",
    Select: "Selected",
    Set: "Set",
    Terminate: "Terminated",
    Union: "Union",
    Update: "Updated"
  },

  /*
  
    Public API

  */
  init(ports, workerPath, middleWare, ...plugins) {
    ports.elmToDb.subscribe(msg => this.elmToDb(msg))
    this.dbToElm = ports.dbToElm;

    this.workerPath = workerPath || this.workerPath;
    this.middleWare = middleWare;
    plugins.forEach(({ name, plugin }) => {
      this.plugins[name] = plugin;
    });
  },

  elmToDb({ msg, data, requestId }) {
    switch (msg) {
      case "Init":
        this.initDB(data);
        break;

      case "Update":
        if (data.mapSet && this.middleWare[data.mapSet]) {
          data.mapSet = this.middleWare[data.mapSet]
        }

        this.tryDB("Update", data, requestId);
        break;

      case "LogStatus":
        this.logStatus(data);
        break;

      case "Transaction":
        this.transaction(data);
        break;

      case "AddMiddleware":
        this.addMidleware(data);
        break;

      case "AddPlugins":
        this.addPlugins(data);
        break;

      default:
        this.tryDB(msg, data, requestId);
    }
  },

  /*
   
    Internal 
   
  */

  async initDB(schema) {
    var connection = this.connectionFor(schema.name);

    connection.on("create", (db) => {
      this.send("Created", {
        dbName: db.name
      });
    })

    connection.on("open", (db) => {
      this.send("Opened", {
        dbName: db.name
      });
    })

    connection.on("upgrade", (db, oldVersion, newVersion) => {
      this.send("Upgraded", {
        dbName: db.name,
        oldVersion: oldVersion,
        newVersion: newVersion
      });
    });

    connection.on("requestQueueEmpty", () => {
      this.send("RequestQueueEmpty", {
        dbName: schema.name
      });
    })

    connection.on("requestQueueFilled", () => {
      this.send("RequestQueueFilled", {
        dbName: schema.name
      });
    })

    await connection.initDb(schema);
  },

  async tryDB(event, data, requestId) {
    var func = event.toLowerCase()
    var connection = this.connectionFor(data.dbName);

    var params;
    switch (event) {
      case "Clear":
        params = data.tableName;
        break;

      case "Drop":
        params = null;
        break;

      case "GetDbList":
        params = null;

      case "Intersect":
        params = { queries: data };
        break;

      case "Terminate":
        params = null;
        break;

      default:
        params = data;
    }

    try {
      var result;
      if (params == null) {
        result = await connection[func]();
      } else {
        switch (event) {
          case "Get":
            result = await connection[func](params.key);
            break;

          case "Set":
            result = await connection[func](params.key, params.value);
            break;

          default:
            result = await connection[func](params);
        }
      }

      this.send(this.response[event], result, requestId);

    } catch (e) {
      this.send("Error", {
        event: event,
        data: data,
        requestId: requestId
      })
    }
  },

  async transaction(data) {
    var connection = this.connectionFor(data.dbName);
    var method = data.method;

    if (data.importScripts) {
      await connection.importScripts(data.importScripts);

    } else if (!window[method] && this.middleWare[method]) {
      window[method] = this.middleWare[method]
    }

    this.tryDB("Transaction", data)
  },

  logStatus(data) {
    var connection = this.connectionFor(data.dbName);

    connection.logStatus = data.logStatus;
  },

  addMiddlware(data) {
    var connection = this.connectionFor(data.dbName);

    data.middleWare.forEach(({ funcName, isWorker }) => {
      if (isWorker) {
        connection.addMiddlware(this.middleWare[funcName], true);
      } else {
        connection.addMiddlware(this.middleWare[funcName]);
      }
    });
  },

  addPlugins(data) {
    var connection = this.connectionFor(data.dbName);

    data.plugins.forEach((name) => {
      connection.addPlugin(this.plugins[name])
    })
  },

  connectionFor(dbName) {
    if (this.conns[dbName] === undefined) {
      this.conns[dbName] = new JsStore.Connection(new Worker(this.workerPath));
    }

    return this.conns[dbName];
  },

  send(event, payload, requestId) {
    if (requestId === undefined) {
      requestId = null;
    }

    this.dbToElm.send({
      event: event,
      payload: payload,
      requestId: requestId
    })
  }
}