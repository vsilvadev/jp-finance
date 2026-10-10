{{flutter_js}}
{{flutter_build_config}}

// The app registers its own service worker from index.html. Do not let the
// deprecated Flutter stub compete for the same Pages scope.
_flutter.loader.load();
