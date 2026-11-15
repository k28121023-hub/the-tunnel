const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
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
