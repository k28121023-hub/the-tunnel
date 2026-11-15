const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
function prepare(directory) {
  const htmlPath = path.join(directory, 'game.html');
  let html = fs.readFileSync(htmlPath, 'utf8');
  const loadingStatusSrc = path.join(__dirname, '..', 'loading-status.js');
  if (fs.existsSync(loadingStatusSrc)) {
    fs.copyFileSync(loadingStatusSrc, path.join(directory, 'loading-status.js'));
  }
  const match = html.match(/const GODOT_CONFIG = (\{[^\n]+\});/);
  if (!match) throw new Error('Godot configuration not found');
  const config = JSON.parse(match[1]);
  const source = config.executable;
  const digest = (...files) => {
    const hash = crypto.createHash('sha256');
    for (const file of files) hash.update(fs.readFileSync(path.join(directory, file)));
    return hash.digest('hex').slice(0, 20);
  };
  const engine = 'engine-' + digest(source+'.js', source+'.wasm');
  // Worklets must keep the engine- prefix: Godot requests
  // <executable>.audio.worklet.js at runtime (not an asset- hash).
  const engineSuffixes = new Set([
    '.js', '.wasm',
    '.audio.worklet.js', '.audio.position.worklet.js',
  ]);
  const names = {};
  for (const file of fs.readdirSync(directory)) {
    if (!file.startsWith(source+'.') || file.endsWith('.html')) continue;
    const suffix = file.slice(source.length);
    names[file] = engineSuffixes.has(suffix)
      ? engine+suffix : 'asset-'+digest(file)+suffix;
  }
  for (const [before, after] of Object.entries(names)) {
    fs.renameSync(path.join(directory,before),path.join(directory,after));
    html = html.split(before).join(after);
  }
  config.executable = engine;
  config.mainPack = names[source+'.pck'];
  config.fileSizes = Object.fromEntries(Object.entries(config.fileSizes).map(([name,size]) => [names[name] || name,size]));
  html = html.replace(/const GODOT_CONFIG = (\{[^\n]+\});/, 'const GODOT_CONFIG = '+JSON.stringify(config)+';');
  const compressed = {};
  for (const name of Object.keys(config.fileSizes)) {
    if (!/\.(wasm|pck)$/.test(name)) continue;
    const original = fs.readFileSync(path.join(directory,name));
    const zipped = zlib.gzipSync(original,{level:9});
    if (!zlib.gunzipSync(zipped).equals(original)) throw new Error('Compression validation failed');
    fs.writeFileSync(path.join(directory,name+'.gz'),zipped);
    compressed[name] = original.length;
    console.log(name+': '+original.length+' -> '+zipped.length+' bytes');
  }
  const loader = fs.readFileSync(path.join(__dirname,'compressed-loader.js'),'utf8').replace('__COMPRESSED_FILES__',JSON.stringify(compressed));
  html = html.replace('<script src="'+engine+'.js"></script>','<script>'+loader+'</script>\n<script src="'+engine+'.js"></script>');
  if (!html.includes('installCompressedDownloads')) throw new Error('Compressed loader injection failed');
  // Start the large downloads as soon as the HTML is parsed, instead of
  // waiting for engine JS to finish loading and then calling fetch.
  const splash = html.match(/id="status-splash"[^>]*src="([^"]+)"/);
  const preloads = [
    splash ? '<link rel="preload" href="'+splash[1]+'" as="image">' : '',
    '<link rel="preload" href="'+engine+'.js" as="script">',
    '<link rel="preload" href="'+engine+'.wasm.gz" as="fetch" crossorigin>',
    '<link rel="preload" href="'+config.mainPack+'.gz" as="fetch" crossorigin>',
  ].filter(Boolean).join('\n\t\t');
  html = html.replace('</title>', '</title>\n\t\t'+preloads);
  html = html.replace('id="status-splash"', 'id="status-splash" fetchpriority="high"');
  // Install a versioned service worker: hashed assets cache-first, HTML network-first.
  // The first visit usually finishes fetching wasm/pck before the worker controls
  // the page, so also precache those URLs after registration using the HTTP cache
  // (force-cache) and avoid a third-visit-only hit.
  const cacheVersion = digest(engine+'.js', engine+'.wasm', config.mainPack);
  const swSource = fs.readFileSync(path.join(__dirname,'sw.js'),'utf8').replaceAll('__CACHE_VERSION__', cacheVersion);
  fs.writeFileSync(path.join(directory,'sw.js'), swSource);
  const precache = [
    engine+'.js',
    engine+'.wasm.gz',
    config.mainPack+'.gz',
    engine+'.audio.worklet.js',
    engine+'.audio.position.worklet.js',
    'loading-status.js',
    splash ? splash[1] : '',
  ].filter((name) => name && fs.existsSync(path.join(directory, name)));
  const swBootstrap = [
    '<script>',
    '(function(){',
    "  if (!('serviceWorker' in navigator)) return;",
    '  var params = new URLSearchParams(location.search);',
    "  if (params.has('nosw') || params.get('sw') === 'off') {",
    '    navigator.serviceWorker.getRegistrations().then(function(rs){',
    '      return Promise.all(rs.map(function(r){ return r.unregister(); }));',
    '    }).then(function(){',
    "      if (window.caches) return caches.keys().then(function(keys){ return Promise.all(keys.map(function(k){ return caches.delete(k); })); });",
    '    });',
    '    return;',
    '  }',
    "  var cacheName = 'tunnel-"+cacheVersion+"';",
    '  var precache = '+JSON.stringify(precache)+';',
    "  navigator.serviceWorker.register('sw.js', {scope: './'}).then(function(){",
    '    return navigator.serviceWorker.ready;',
    '  }).then(function(){',
    '    if (!window.caches) return;',
    '    return caches.open(cacheName).then(function(cache){',
    '      return Promise.all(precache.map(function(url){',
    '        return cache.match(url).then(function(hit){',
    '          if (hit) return;',
    "          return fetch(url, {cache: 'force-cache'}).then(function(res){",
    '            if (res && res.ok) return cache.put(url, res);',
    '          });',
    '        });',
    '      }));',
    '    });',
    '  });',
    '})();',
    '</script>',
  ].join('\n');
  if (html.includes('</body>')) html = html.replace('</body>', swBootstrap+'\n</body>');
  else html += swBootstrap;

  fs.writeFileSync(path.join(directory,'index.html'),html);
  fs.unlinkSync(htmlPath);
  const required = [...Object.keys(config.fileSizes),engine+'.js',config.mainPack];
  for (const worklet of [engine+'.audio.worklet.js', engine+'.audio.position.worklet.js']) {
    if (fs.existsSync(path.join(directory, worklet))) required.push(worklet);
    else console.warn('Missing audio worklet, it will 404 at runtime: '+worklet);
  }
  for (const name of required) {
    if (!name || !fs.existsSync(path.join(directory,name))) throw new Error('Missing published asset: '+name);
  }
  if (!fs.existsSync(path.join(directory,'sw.js'))) throw new Error('Service worker was not written');
  console.log(JSON.stringify({engine,mainPack:config.mainPack,fileSizes:config.fileSizes,cacheVersion},null,2));
  return config;
}
module.exports = prepare;
if (require.main === module) prepare(process.argv[2] || 'build/web');

