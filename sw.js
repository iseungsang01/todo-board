// 앱 화면(이 폴더 파일 + CDN 스크립트·글꼴)을 캐시해 인터넷 없이도 열리게 한다.
// 이 폴더 파일은 네트워크 먼저(새 판이 바로 보이게), CDN은 주소에 버전이 박혀 있어 캐시 먼저.
// Supabase 호출은 건드리지 않는다 — 목록 데이터는 index.html이 localStorage에 따로 캐시한다.
const CACHE = "todo-board-v3";
const SHELL = [
  "./", "index.html", "manifest.webmanifest", "icon.svg",
  "https://cdnjs.cloudflare.com/ajax/libs/Sortable/1.15.2/Sortable.min.js",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js",
];
const CDN_HOSTS = ["cdnjs.cloudflare.com", "cdn.jsdelivr.net", "fonts.googleapis.com", "fonts.gstatic.com"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin === location.origin) {
    // no-cache: GitHub Pages의 10분 브라우저 캐시를 건너뛰고 서버에 새 판이 있는지 매번 물어본다 (휴대폰 홈 화면 앱이 옛 화면에 머무르지 않게)
    e.respondWith(fetch(req, { cache: "no-cache" })
      .then((res) => { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); return res; })
      .catch(async () => (await caches.match(req, { ignoreSearch: true })) || caches.match("./")));
  } else if (CDN_HOSTS.includes(url.hostname)) {
    // <script>로 받은 것은 불투명(opaque) 응답으로 캐시되는데, 같은 주소를 fetch()(CORS)로 다시 부르면
    // 그 불투명 응답은 쓸 수 없어 실패한다 (onnxruntime-web이 웹 워커를 띄울 때 자기 스크립트를 이렇게 다시 받는다).
    // 그럴 때는 네트워크에서 CORS로 받아 캐시를 바꿔 둔다 — CORS 응답은 <script>에도 그대로 쓸 수 있다.
    e.respondWith(caches.match(req).then((hit) => (hit && !(hit.type === "opaque" && req.mode === "cors")) ? hit : fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(req, copy));
      return res;
    })));
  }
});
