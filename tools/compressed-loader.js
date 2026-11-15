(function installCompressedDownloads(files) {
  if (typeof DecompressionStream === 'undefined') return;
  const originalFetch = window.fetch.bind(window);
  const allowed = new Map(Object.entries(files).map(([name,size]) => [new URL(name,document.baseURI).href,size]));
  window.fetch = async function(input, options) {
    const url = new URL(typeof input === 'string' ? input : input.url,document.baseURI);
    const size = allowed.get(url.href);
    if (!size || (options && options.method && options.method !== 'GET')) return originalFetch(input,options);
    try {
      const response = await originalFetch(url.href+'.gz',options);
      if (!response.ok || !response.body) return originalFetch(input,options);
      const body = response.headers.get('Content-Encoding') === 'gzip'
        ? response.body : response.body.pipeThrough(new DecompressionStream('gzip'));
      return new Response(body,{headers:{'Content-Type':url.pathname.endsWith('.wasm')?'application/wasm':'application/octet-stream','Content-Length':String(size)}});
    } catch (_) {
      return originalFetch(input,options);
    }
  };
})(__COMPRESSED_FILES__);
