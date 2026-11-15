# The Dungeon

Godot 4.5.1 製作的鍵盤操作冒險遊戲，包含第二關死神戰與英文答題挑戰。

## 操作

- A / D 或左右方向鍵：移動
- W / 上方向鍵 / Shift：跳躍
- S / 下方向鍵：蹲下
- 空白鍵：攻擊
- Q：切換武器
- R：重新開始目前關卡

建議使用電腦版瀏覽器遊玩。點一下遊戲畫面即可取得鍵盤焦點。

## 開發與發布

以 Godot 4.5.1 開啟 `project.godot`。主場景為第一關。
推送至 `main` 後，GitHub Actions 會匯出單執行緒 Web 版本並發布至 GitHub Pages。
儲存庫 Settings → Pages 的 Source 必須設為 GitHub Actions。

