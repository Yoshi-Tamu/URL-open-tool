# Chrome JSON URL Opener

JSONファイル、または貼り付けたJSONに含まれるURLをChromeでまとめて開くWindows用の小さなGUIツールです。Pythonは不要で、Windows PowerShellを使って動作します。

## 起動

`start_chrome_json_opener.bat` をダブルクリックしてください。

## JSON形式

推奨形式:

```json
{
  "urls": [
    "https://example.com",
    "https://www.python.org/"
  ]
}
```

次の形式も使えます。

```json
["https://example.com", "https://www.python.org/"]
```

```json
{
  "urls": [
    {"url": "https://example.com", "title": "Example"}
  ]
}
```

`http://` と `https://` のURLだけを対象にします。`title` などURL以外の項目は無視されます。

## コマンドライン

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File chrome_json_opener.ps1 links.json
```

引数を省略して標準入力から渡すこともできます。

```text
type links.json | powershell.exe -NoProfile -ExecutionPolicy Bypass -File chrome_json_opener.ps1
```
