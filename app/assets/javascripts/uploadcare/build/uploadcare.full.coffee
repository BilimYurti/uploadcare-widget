# = require ../vendor/jquery.3.4.1.min.js
# = require ./_widget.coffee
# = require_directory ../locale

uploadcare.jQuery.noConflict(true)

uploadcare.expose('locales', (key for key of uploadcare.locale.translations))
