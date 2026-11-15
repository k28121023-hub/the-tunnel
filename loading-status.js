// Keep loading progress readable and offer recovery without hiding engine errors.
window.addEventListener('DOMContentLoaded', () => {
  const status = document.getElementById('status');
  const progress = document.getElementById('status-progress');
  if (!status || !progress) return;
  const panel = document.createElement('div');
  panel.style.cssText = 'position:absolute;bottom:16%;left:8%;right:8%;text-align:center;font:16px sans-serif;color:#fff;z-index:2';
  const label = document.createElement('div');
  label.setAttribute('role','status');
  const retry = document.createElement('button');
  retry.textContent = '重新載入遊戲';
  retry.style.cssText = 'display:none;margin:12px auto;padding:12px 20px;font-size:16px;border:1px solid #ffe5a2;border-radius:8px;background:#202a39;color:white;cursor:pointer';
  retry.onclick = () => {
    const url = new URL(location.href);
    url.searchParams.set('reload', Date.now().toString());
    location.replace(url.href);
  };
  panel.append(label,retry);
  status.append(panel);
  const started = Date.now();
  const timer = setInterval(() => {
    if (!status.isConnected) { clearInterval(timer); return; }
    const loaded = Number(progress.value);
    const total = Number(progress.max);
    if (progress.hasAttribute('value') && total > 1) {
      label.textContent = loaded >= total
        ? '下載完成，正在啟動遊戲…'
        : `正在下載遊戲 ${Math.floor(loaded/total*100)}%（${(loaded/1048576).toFixed(1)} / ${(total/1048576).toFixed(1)} MB）`;
    } else {
      label.textContent = '正在準備遊戲，首次載入需要較久時間…';
    }
    if (Date.now()-started > 25000) {
      retry.style.display = 'block';
      retry.title = '若進度長時間沒有變化，點此重新下載啟動頁';
    }
  }, 500);
});
