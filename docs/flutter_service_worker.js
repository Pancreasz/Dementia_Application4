'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "6fb54808317edb75f9b78fc8685b1697",
"assets/AssetManifest.bin.json": "b3d66795452059f64b29c37b6d058d34",
"assets/AssetManifest.json": "933f77cb912e7025199791a9fad0c2f5",
"assets/assets/camel.png": "5660ed252c9644f4badc4a71fb718733",
"assets/assets/cube.png": "43cc4b7540ad5f1f3327e4528af8083f",
"assets/assets/img1.jpg": "9aa49a541e72a5d29c2ab0fe0b52075a",
"assets/assets/img10.jpg": "20fc4c9e9a2ff6143603f010353164f0",
"assets/assets/img2.jpg": "e31733978f498f6e814e234c09e5b641",
"assets/assets/img3.jpg": "ee621352f41183578666552632659da1",
"assets/assets/img4.jpg": "3053de0021ee6303834c687e395fa089",
"assets/assets/img5.jpg": "e8226835fe52ab773a409183fb7ec272",
"assets/assets/img6.jpg": "f5e1e56c05cf87d1369d879f8ba755d3",
"assets/assets/img7.jpg": "dd354d17cb6176d9fd93b2c67209ecb5",
"assets/assets/img8.jpg": "6851053f03395ca620ad5a09c5160a0e",
"assets/assets/img9.jpg": "ba5307bbf01b5360f6d09cc6cc2ea1c0",
"assets/assets/larksen_tutorial.gif": "6f0b0b72f9c2a858545e2f49cf6a697c",
"assets/assets/lion.png": "744226f75c64b387bb1a4e46ff9eb470",
"assets/assets/moca/audio/digit-0.wav": "378f696496a8a1883593ea09cea31989",
"assets/assets/moca/audio/digit-1.wav": "547f32b6dd2fb54dffe32bc1a0096307",
"assets/assets/moca/audio/digit-2.wav": "587ac4dece6d0eae1663073384a166e5",
"assets/assets/moca/audio/digit-3.wav": "791a3e5b78f9e66b49f3197f612c50fa",
"assets/assets/moca/audio/digit-4.wav": "e0be1a9be62e65b67c8f254fa077a503",
"assets/assets/moca/audio/digit-5.wav": "e4b22f93776338f83d8577e4cd497f12",
"assets/assets/moca/audio/digit-6.wav": "077cdb6cdb1e1db2dbe44f7d06d8b3f0",
"assets/assets/moca/audio/digit-7.wav": "57725cde4242468de797898ad78d4ee9",
"assets/assets/moca/audio/digit-8.wav": "3efa0a9dcd09abf21e10f045976e9b0f",
"assets/assets/moca/audio/digit-9.wav": "fb611b4a23373019b47ae224dfd24664",
"assets/assets/moca/audio/digits-backward.wav": "06b37734268ad1eadd6829d91f482fa6",
"assets/assets/moca/audio/digits-forward.wav": "c9875b7ee09680f16a7db86c4937aef5",
"assets/assets/moca/audio/eng-digit-0.mp3": "1528530c19c7e1956464af5c81a6e7ba",
"assets/assets/moca/audio/eng-digit-1.mp3": "65852790e3d7b371bda577c854e78fc7",
"assets/assets/moca/audio/eng-digit-2.mp3": "1aba8c9f4630054f0e85c46916d25949",
"assets/assets/moca/audio/eng-digit-3.mp3": "d250970c00b6d3eb8dfb72f4cacac692",
"assets/assets/moca/audio/eng-digit-4.mp3": "74425eab5abc30870b65a9b95df6bfbf",
"assets/assets/moca/audio/eng-digit-5.mp3": "1ee2b5b9680bdd3c639bb5644df45806",
"assets/assets/moca/audio/eng-digit-6.mp3": "0130098280c5b84a785365b0e3dcb1d3",
"assets/assets/moca/audio/eng-digit-7.mp3": "c27a294f2467e42fe162c470c16bc0a0",
"assets/assets/moca/audio/eng-digit-8.mp3": "a2d2c782fc489a2b12b48e8430826f4b",
"assets/assets/moca/audio/eng-digit-9.mp3": "cf0d60f1d7a5c124ed62c21624c02c50",
"assets/assets/moca/audio/eng-digits-backward.m4a": "295b7ecd9d00eb0a9a63691a02a8e6c5",
"assets/assets/moca/audio/eng-digits-forward.m4a": "fc442f9994456295276406242a9460ea",
"assets/assets/moca/audio/eng-sentence-1.m4a": "ccce0a7b40f399592236c3f3330bd148",
"assets/assets/moca/audio/eng-sentence-2.m4a": "aa22ec1a025484d51a19864cab4f1e72",
"assets/assets/moca/audio/sentence-1.wav": "7e15993dc7b5223c77bb86b05f4762df",
"assets/assets/moca/audio/sentence-2.wav": "105a599c97369364d0fc4603823a6399",
"assets/assets/rhino.png": "e1fd93b25bbd4f0da699e7809d0f24fc",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "c27252786633610f59c822eeb8ed4d15",
"assets/NOTICES": "48ad57502eb578d98016c6bb44ccac94",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "62e560efd80c23d79cbb8449f31a207e",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "6fe794935ddd7936e4b6810dd797e875",
"/": "6fe794935ddd7936e4b6810dd797e875",
"main.dart.js": "dfcef639d6b2e440aba6e64f91d2dca1",
"manifest.json": "fbf700be7d8c00b589cdea77b7a1d85a",
"version.json": "776fdafe0136631a7a1aa5a7cc8246d3"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
