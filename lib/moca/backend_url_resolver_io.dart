/// Desktop/mobile: no address bar to read a `?backend=` override from, and no
/// localStorage to remember one in. Always the compiled-in default.
String resolveBackendBaseUrl(String compiledDefault) => compiledDefault;
