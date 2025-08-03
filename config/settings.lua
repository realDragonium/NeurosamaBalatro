local Settings = {}

Settings.WEBSOCKET_HOST = "localhost"
Settings.WEBSOCKET_PORT = 8000
Settings.WEBSOCKET_PATH = "/"
Settings.CONNECTION_TIMEOUT = 5.0
Settings.RECONNECT_DELAY = 5.0
Settings.MAX_RECONNECT_ATTEMPTS = -1  -- -1 means infinite reconnect attempts

Settings.DEBUG_MODE = false
Settings.VERBOSE_LOGGING = true
Settings.AUTO_RECONNECT = true  -- Enable infinite reconnection every 5 seconds


return Settings