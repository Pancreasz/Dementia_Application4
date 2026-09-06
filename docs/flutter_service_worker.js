'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "abab87484724660bce29973507cda7d4",
"assets/AssetManifest.bin.json": "3a833dd3c1181db40840a0e8ce600b0e",
"assets/AssetManifest.json": "1204cd7e02788d879f6af6127516735f",
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
"assets/assets/moca/audio/digit-0.wav": "e85650eee694b6cc7ff6fd938e5292a8",
"assets/assets/moca/audio/digit-1.wav": "1e9936b44972a6131d94b46ac000c55d",
"assets/assets/moca/audio/digit-2.wav": "21aa8fe6f507cfaf863e37d7c3a3d877",
"assets/assets/moca/audio/digit-3.wav": "23a355ae92b1257a7de5c2109d2011f6",
"assets/assets/moca/audio/digit-4.wav": "104b48877aa0777649b29684b290ab0c",
"assets/assets/moca/audio/digit-5.wav": "a3ce05602772e439832e8aec5b2b9d9f",
"assets/assets/moca/audio/digit-6.wav": "12614336a16ea70519d9f1ecf1533674",
"assets/assets/moca/audio/digit-7.wav": "6c6c09b4463d7efac05ff35e0f6814ff",
"assets/assets/moca/audio/digit-8.wav": "1317776202aec656075ca6ba8446749b",
"assets/assets/moca/audio/digit-9.wav": "3f1190cf44873f395c97f25204d41f72",
"assets/assets/moca/audio/digits-backward.wav": "db19db07ecd235676623a5c9e511a44f",
"assets/assets/moca/audio/digits-forward.wav": "c33776aaad97e024ac6fd6ce267f3b4e",
"assets/assets/moca/audio/eng-digit-0.wav": "4b23d5d5deb90734bcfe34d97753715f",
"assets/assets/moca/audio/eng-digit-1.wav": "5e4731cbc8c4f5e4d96cd0dcff0ddbb6",
"assets/assets/moca/audio/eng-digit-2.wav": "0af028a1ea24e48c54be5baac97c19ce",
"assets/assets/moca/audio/eng-digit-3.wav": "b702d4ff113c128eb1090b76b32d17f3",
"assets/assets/moca/audio/eng-digit-4.wav": "9edf07ac80c69de1f26016f30e92504a",
"assets/assets/moca/audio/eng-digit-5.wav": "d898defc0b55b10ad2eaf0675410b99f",
"assets/assets/moca/audio/eng-digit-6.wav": "0c5f4aa1b9e52a8ff8a3fe43b76178e2",
"assets/assets/moca/audio/eng-digit-7.wav": "8848aa89d855972ca41005d527f0a483",
"assets/assets/moca/audio/eng-digit-8.wav": "b4ad283b39651527dc02f7309b95d2ec",
"assets/assets/moca/audio/eng-digit-9.wav": "3e2c9fc4eeb0dd382f944e260c763d31",
"assets/assets/moca/audio/eng-digits-backward.wav": "4d97ca581c34ab67aa32b57f8b748948",
"assets/assets/moca/audio/eng-digits-forward.wav": "60173f7b5d6656beb974b184ff85d243",
"assets/assets/moca/audio/eng-sentence-1.wav": "294780f406ebf1b694430621d2b9a7c3",
"assets/assets/moca/audio/eng-sentence-2.wav": "f811cd8e9b4266e73ad2b0e6c397d8c2",
"assets/assets/moca/audio/eng-vigilance.wav": "33906d5a8faff0bb22cfd84d999820d0",
"assets/assets/moca/audio/sentence-1.wav": "0ceba25c0e5868610b9a2f493cadc7ca",
"assets/assets/moca/audio/sentence-2.wav": "b51d6872ec83e6d5a3c4a4eadd13cf43",
"assets/assets/moca/audio/vigilance.wav": "298c46df183cfa5ae1c5c11e55cb050a",
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
"flutter_bootstrap.js": "72bb483d53d47068a832dde68c66a908",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "6fe794935ddd7936e4b6810dd797e875",
"/": "6fe794935ddd7936e4b6810dd797e875",
"main.dart.js": "4ef208c0fd55a809145856c3acae92c0",
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
