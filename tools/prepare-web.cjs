const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
function prepare(directory) {
  const htmlPath = path.join(directory, 'game.html');
  let html = fs.readFileSync(htmlPath, 'utf8');
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
  const names = {};
  for (const file of fs.readdirSync(directory)) {
    if (!file.startsWith(source+'.') || file.endsWith('.html')) continue;
    const suffix = file.slice(source.length);
    names[file] = ['.js','.wasm'].includes(suffix)
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
  fs.writeFileSync(path.join(directory,'index.html'),html);
  fs.unlinkSync(htmlPath);
  for (const name of [...Object.keys(config.fileSizes),engine+'.js',config.mainPack]) {
    if (!name || !fs.existsSync(path.join(directory,name))) throw new Error('Missing published asset: '+name);
  }
  console.log(JSON.stringify({engine,mainPack:config.mainPack,fileSizes:config.fileSizes},null,2));
  return config;
}
module.exports = prepare;
if (require.main === module) prepare(process.argv[2] || 'build/web');

