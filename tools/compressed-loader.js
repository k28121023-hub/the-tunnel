(function installCompressedDownloads(config) {
  if (typeof DecompressionStream === 'undefined') return;
  const files = config && config.files ? config.files : config;
  const decoderUrl = config && config.decoder ? config.decoder : '';
  const originalFetch = window.fetch.bind(window);
  const allowed = new Map(Object.entries(files).map(([name, size]) => [new URL(name, document.baseURI).href, size]));

  const Result = { Error: 0, Success: 1, NeedsMoreInput: 2, NeedsMoreOutput: 3 };

  // Classic-script port of tiny-brotli-dec-wasm's BrotliDecompressStream.
  class BrotliDecompressStream {
    constructor(module) {
      const env = { memory_grown: this._reattach.bind(this) };
      const instance = new WebAssembly.Instance(module, { env });
      this._wasm = instance.exports;
      this._reattach();
      this._state = this._wasm.BrotliDecoderCreateInstance(0, 0, 0);
      this._available_in_ptr = this._wasm.malloc(4);
      this._available_out_ptr = this._wasm.malloc(4);
      this._next_in_ptr_ptr = this._wasm.malloc(4);
      this._next_out_ptr_ptr = this._wasm.malloc(4);
      this._next_in_ptr = 0;
      this._next_out_ptr = 0;
      this._in_size = 0;
      this._out_size = 0;
      this._lastInputOffset = 0;
      this._result = 0;
    }
    _reattach() {
      const mem = this._wasm.memory.buffer;
      this._mem8 = new Uint8Array(mem);
      this._mem32 = new Uint32Array(mem);
    }
    _setup_in(size) {
      if (size > this._in_size) {
        this._in_size = size;
        this._wasm.free(this._next_in_ptr);
        this._next_in_ptr = this._wasm.malloc(size);
      }
      this._mem32[this._available_in_ptr >> 2] = size;
      this._mem32[this._next_in_ptr_ptr >> 2] = this._next_in_ptr;
    }
    _setup_out(size) {
      if (size > this._out_size) {
        this._out_size = size;
        this._wasm.free(this._next_out_ptr);
        this._next_out_ptr = this._wasm.malloc(size);
      }
      this._mem32[this._available_out_ptr >> 2] = size;
      this._mem32[this._next_out_ptr_ptr >> 2] = this._next_out_ptr;
    }
    lastInputOffset() { return this._lastInputOffset; }
    result() { return this._result; }
    dec(input, output_size) {
      this._setup_in(input.byteLength);
      this._setup_out(output_size);
      this._mem8.set(input, this._next_in_ptr);
      this._result = this._wasm.BrotliDecoderDecompressStream(
        this._state,
        this._available_in_ptr,
        this._next_in_ptr_ptr,
        this._available_out_ptr,
        this._next_out_ptr_ptr,
        0
      );
      const used_input = input.byteLength - this._mem32[this._available_in_ptr >> 2];
      const used_output = output_size - this._mem32[this._available_out_ptr >> 2];
      this._lastInputOffset = used_input;
      return this._mem8.slice(this._next_out_ptr, this._next_out_ptr + used_output);
    }
    free() {
      this._wasm.free(this._available_in_ptr);
      this._wasm.free(this._available_out_ptr);
      this._wasm.free(this._next_in_ptr_ptr);
      this._wasm.free(this._next_out_ptr_ptr);
      this._wasm.free(this._next_in_ptr);
      this._wasm.free(this._next_out_ptr);
      this._wasm.BrotliDecoderDestroyInstance(this._state);
    }
  }

  function createBrotliTransformStream(module) {
    const dec = new BrotliDecompressStream(module);
    return new TransformStream({
      transform(chunk, controller) {
        let input = chunk instanceof Uint8Array ? chunk : new Uint8Array(chunk);
        while (true) {
          const output = dec.dec(input, 65536);
          if (output.byteLength) controller.enqueue(output);
          const code = dec.result();
          input = input.subarray(dec.lastInputOffset());
          if (code === Result.NeedsMoreOutput) continue;
          if (code === Result.NeedsMoreInput) break;
          if (code === Result.Success) return;
          throw new Error('brotli decode failed');
        }
      },
      flush() {
        try { dec.free(); } catch (_) { /* already freed */ }
      },
    });
  }

  async function loadBrotliModule() {
    if (!decoderUrl || typeof WebAssembly === 'undefined') return null;
    const href = new URL(decoderUrl, document.baseURI).href;
    const gz = await getCachedOrFetch(href);
    if (!gz.ok || !gz.body) return null;
    const body = gz.headers.get('Content-Encoding') === 'gzip'
      ? gz.body
      : gz.body.pipeThrough(new DecompressionStream('gzip'));
    const bytes = await new Response(body).arrayBuffer();
    return WebAssembly.compile(bytes);
  }

  async function getCachedOrFetch(href, options) {
    try {
      if (window.caches) {
        const hit = await caches.match(href);
        if (hit) return hit;
      }
    } catch (_) { /* Cache API unavailable */ }
    return originalFetch(href, options);
  }

  function decodedResponse(body, url, size) {
    return new Response(body, {
      headers: {
        'Content-Type': url.pathname.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream',
        'Content-Length': String(size),
      },
    });
  }

  let decoderModulePromise = decoderUrl ? loadBrotliModule() : null;

  window.fetch = async function(input, options) {
    const url = new URL(typeof input === 'string' ? input : input.url, document.baseURI);
    const size = allowed.get(url.href);
    if (!size || (options && options.method && options.method !== 'GET')) return originalFetch(input, options);

    if (decoderModulePromise && url.pathname.endsWith(".wasm")) {
      try {
        const module = await decoderModulePromise;
        if (module) {
          const response = await getCachedOrFetch(url.href + '.br', options);
          if (response.ok && response.body) {
            const body = response.body.pipeThrough(createBrotliTransformStream(module));
            return decodedResponse(body, url, size);
          }
        }
      } catch (_) { /* fall through to gzip */ }
    }

    try {
      const response = await getCachedOrFetch(url.href + '.gz', options);
      if (!response.ok || !response.body) return originalFetch(input, options);
      const body = response.headers.get('Content-Encoding') === 'gzip'
        ? response.body
        : response.body.pipeThrough(new DecompressionStream('gzip'));
      return decodedResponse(body, url, size);
    } catch (_) {
      return originalFetch(input, options);
    }
  };
})(__COMPRESSED_CONFIG__);
