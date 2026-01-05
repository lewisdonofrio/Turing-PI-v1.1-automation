import pyinotify

# Expose the constants include-server expects
IN_CREATE = pyinotify.IN_CREATE
IN_DELETE = pyinotify.IN_DELETE
IN_MODIFY = pyinotify.IN_MODIFY
IN_MOVED_FROM = pyinotify.IN_MOVED_FROM
IN_MOVED_TO = pyinotify.IN_MOVED_TO

# Expose WatchManager and Notifier
WatchManager = pyinotify.WatchManager
Notifier = pyinotify.Notifier
