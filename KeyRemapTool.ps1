# ThinkPad X12 Detachable Gen 1 Folio Keyboard (Integrated Edition: JIS / UK / US)
# Firmware Key Remapper & Disabler
# Target Firmware: Hera_KB_APROM_v39_UT0N.bin & KB-ISP.exe

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) {
    if ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
}
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = "D:\4.0inch_ESP32-4848S040\firm\wpf" }
$BinPath   = Join-Path $ScriptDir "FW\Hera_KB_APROM_v39_UT0N.bin"
$IspPath   = Join-Path $ScriptDir "KB-ISP.exe"
$BinBak    = Join-Path $ScriptDir "FW\Hera_KB_APROM_v39_UT0N.bin.orig.bak"
$IspBak    = Join-Path $ScriptDir "KB-ISP.exe.orig.bak"

# ファームウェア構造定数
$MATRIX_OFFSET      = 0x5CD0  # 16 Cols x 8 Rows x 4 Bytes = 512 Bytes (0x5CD0..0x5ECF)
$FN_COORD_OFFSET    = 0x5C50  # 32 Entries x 4 Bytes (Col << 16 | Row)
$FN_FNLOCK_OFFSET   = 0x5B50  # 32 Entries x 4 Bytes (FnLock ON / Standard F1-F12 mode)
$FN_MEDIA_OFFSET    = 0x5BD0  # 32 Entries x 4 Bytes (Default Media / Hotkey mode)
$EXPECTED_BIN_SIZE  = 24624   # 0x6030 bytes

# KB-ISP.exe 内部オフセット定数
$ISP_EMBED_BIN_OFF  = 0x23B630 # KB-ISP.exe 内の埋め込みファームウェア先頭オフセット (24,624 bytes)
$ISP_SHUTDOWN_OFF   = 0x0187AC # shutdown -f -r -t 0 呼び出し (13 bytes)
$ISP_POWERCHK_OFF   = 0x01CCD0 # AC電源・バッテリー残量25%チェック (20 bytes)
$ISP_VERCHK_OFF     = 0x01CCB6 # バージョンチェック分岐 (2 bytes: 74 18 -> EB 18)

$ORIG_SHUTDOWN_BYTES = [byte[]](0x68, 0x34, 0x48, 0x5A, 0x00, 0xE8, 0x39, 0x00, 0x15, 0x00, 0x83, 0xC4, 0x04)
$ORIG_POWERCHK_BYTES = [byte[]](0x80, 0x7D, 0x80, 0x01, 0x0F, 0x85, 0x07, 0x03, 0x00, 0x00, 0x80, 0x7D, 0x82, 0x19, 0x0F, 0x82, 0x17, 0x03, 0x00, 0x00)
$ORIG_VERCHK_BYTES   = [byte[]](0x74, 0x18)

# USB HID キーコード辞書（UK刻印 ＆ JIS解釈の両対応表記）
$HidKeyCatalog = @(
    [PSCustomObject]@{ Code = [uint32]0x00000000; Name = "【無効化 (Disable)】"; Short = "無効"; Category = "0. 特殊・無効化" }
    [PSCustomObject]@{ Code = [uint32]0x02000000; Name = "Fn キー (ハードウェアFn)"; Short = "Fn"; Category = "0. 特殊・無効化" }

    # 修飾キー・IME
    [PSCustomObject]@{ Code = [uint32]0x000000E0; Name = "左 Ctrl (LCtrl)"; Short = "左Ctrl"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E1; Name = "左 Shift (LShift)"; Short = "左Shift"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E2; Name = "左 Alt (LAlt)"; Short = "左Alt"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E3; Name = "左 Win / GUI (LWin)"; Short = "Win"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E4; Name = "右 Ctrl (RCtrl)"; Short = "右Ctrl"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E5; Name = "右 Shift (RShift)"; Short = "右Shift"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E6; Name = "AltGr / 右 Alt (RAlt)"; Short = "AltGr"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x000000E7; Name = "右 Win / GUI (RWin)"; Short = "右Win"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x00000039; Name = "CapsLock (JIS: 英数)"; Short = "CapsLock"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x00000035; Name = '` ¬ ¦ [左上キー] (JIS: 半角/全角)'; Short = '` / 半全'; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x0000008B; Name = "無変換 (JIS Int5 / IME OFF等)"; Short = "無変換"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x0000008A; Name = "変換 (JIS Int4 / IME ON等)"; Short = "変換"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x00000088; Name = "カタカナ/ひらがな (JIS Int2)"; Short = "かな"; Category = "1. 修飾キー・IME" }
    [PSCustomObject]@{ Code = [uint32]0x00000065; Name = "アプリケーション (Menu)"; Short = "Menu"; Category = "1. 修飾キー・IME" }

    # 制御・ナビゲーション
    [PSCustomObject]@{ Code = [uint32]0x00000029; Name = "Esc"; Short = "Esc"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000002B; Name = "Tab"; Short = "Tab"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000002C; Name = "Space (空白)"; Short = "Space"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000028; Name = "Enter (改行)"; Short = "Enter"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000002A; Name = "Backspace (BS)"; Short = "BS"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000004C; Name = "Delete (Del)"; Short = "Delete"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000049; Name = "Insert (Ins)"; Short = "Insert"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000004A; Name = "Home"; Short = "Home"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000004D; Name = "End"; Short = "End"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000004B; Name = "PageUp (PgUp)"; Short = "PgUp"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000004E; Name = "PageDown (PgDn)"; Short = "PgDn"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000052; Name = "↑ (Up Arrow)"; Short = "↑"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000051; Name = "↓ (Down Arrow)"; Short = "↓"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000050; Name = "← (Left Arrow)"; Short = "←"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x0000004F; Name = "→ (Right Arrow)"; Short = "→"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000046; Name = "PrintScreen (PrtSc)"; Short = "PrtSc"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000047; Name = "ScrollLock"; Short = "ScrLk"; Category = "2. 制御・移動キー" }
    [PSCustomObject]@{ Code = [uint32]0x00000048; Name = "Pause / Break"; Short = "Pause"; Category = "2. 制御・移動キー" }

    # ファンクションキー
    [PSCustomObject]@{ Code = [uint32]0x0000003A; Name = "F1"; Short = "F1"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000003B; Name = "F2"; Short = "F2"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000003C; Name = "F3"; Short = "F3"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000003D; Name = "F4"; Short = "F4"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000003E; Name = "F5"; Short = "F5"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000003F; Name = "F6"; Short = "F6"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000040; Name = "F7"; Short = "F7"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000041; Name = "F8"; Short = "F8"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000042; Name = "F9"; Short = "F9"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000043; Name = "F10"; Short = "F10"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000044; Name = "F11"; Short = "F11"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000045; Name = "F12"; Short = "F12"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000068; Name = "F13"; Short = "F13"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000069; Name = "F14"; Short = "F14"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000006A; Name = "F15"; Short = "F15"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000006B; Name = "F16"; Short = "F16"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000006C; Name = "F17"; Short = "F17"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000006D; Name = "F18"; Short = "F18"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000006E; Name = "F19"; Short = "F19"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x0000006F; Name = "F20"; Short = "F20"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000070; Name = "F21"; Short = "F21"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000071; Name = "F22"; Short = "F22"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000072; Name = "F23"; Short = "F23"; Category = "3. ファンクション (F1-F24)" }
    [PSCustomObject]@{ Code = [uint32]0x00000073; Name = "F24"; Short = "F24"; Category = "3. ファンクション (F1-F24)" }

    # アルファベット (A-Z)
    [PSCustomObject]@{ Code = [uint32]0x00000004; Name = "A"; Short = "A"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000005; Name = "B"; Short = "B"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000006; Name = "C"; Short = "C"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000007; Name = "D"; Short = "D"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000008; Name = "E"; Short = "E"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000009; Name = "F"; Short = "F"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000000A; Name = "G"; Short = "G"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000000B; Name = "H"; Short = "H"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000000C; Name = "I"; Short = "I"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000000D; Name = "J"; Short = "J"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000000E; Name = "K"; Short = "K"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000000F; Name = "L"; Short = "L"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000010; Name = "M"; Short = "M"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000011; Name = "N"; Short = "N"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000012; Name = "O"; Short = "O"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000013; Name = "P"; Short = "P"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000014; Name = "Q"; Short = "Q"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000015; Name = "R"; Short = "R"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000016; Name = "S"; Short = "S"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000017; Name = "T"; Short = "T"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000018; Name = "U"; Short = "U"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x00000019; Name = "V"; Short = "V"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000001A; Name = "W"; Short = "W"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000001B; Name = "X"; Short = "X"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000001C; Name = "Y"; Short = "Y"; Category = "4. アルファベット (A-Z)" }
    [PSCustomObject]@{ Code = [uint32]0x0000001D; Name = "Z"; Short = "Z"; Category = "4. アルファベット (A-Z)" }

    # 数字・記号 (UK基準 ＋ JIS解釈併記)
    [PSCustomObject]@{ Code = [uint32]0x0000001E; Name = "1 (!)"; Short = "1"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x0000001F; Name = "2 (`")"; Short = "2"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000020; Name = "3 (£) [JIS: 3 #]"; Short = "3"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000021; Name = "4 ($ €)"; Short = "4"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000022; Name = "5 (%)"; Short = "5"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000023; Name = "6 (^) [JIS: 6 &]"; Short = "6"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000024; Name = "7 (&) [JIS: 7 ']"; Short = "7"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000025; Name = "8 (*) [JIS: 8 (]"; Short = "8"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000026; Name = "9 (() [JIS: 9 )]"; Short = "9"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000027; Name = "0 ()) [JIS: 0]"; Short = "0"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x0000002D; Name = "- (_) [JIS: - =]"; Short = "-"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x0000002E; Name = "= (+) [JIS: ^ ~]"; Short = "="; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x0000002F; Name = '[ ({) [JIS: @ `]'; Short = "["; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000030; Name = "] (}) [JIS: [ {]"; Short = "]"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000033; Name = "; (:) [JIS: ; +]"; Short = ";"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000034; Name = "' (@) [JIS: : *]"; Short = "'"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000032; Name = "# (~) [JIS: ] } (む)]"; Short = "#"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000064; Name = "＼ (|) [左Shift隣 ISOキー]"; Short = "ISO＼"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000036; Name = ", (<)"; Short = ","; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000037; Name = ". (>)"; Short = "."; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000038; Name = "/ (?)"; Short = "/"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000089; Name = "¥ (|) [JIS Int3: 右上円記号]"; Short = "JIS¥"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000087; Name = "＼ (_) [JIS Int1: ろキー]"; Short = "JISろ(＼)"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000031; Name = "＼ (|) [US ANSI Backslash]"; Short = "US＼"; Category = "5. 数字・記号 (UK/JIS)" }
    [PSCustomObject]@{ Code = [uint32]0x00000063; Name = "テンキー . (KP Dot)"; Short = "KP."; Category = "5. 数字・記号 (UK/JIS)" }
)

$HidCodeToItem = @{}
foreach ($item in $HidKeyCatalog) {
    $HidCodeToItem[$item.Code] = $item
}

function Get-KeyShortLabel([uint32]$code) {
    if ($HidCodeToItem.ContainsKey($code)) {
        return $HidCodeToItem[$code].Short
    }
    return ("0x{0:X2}" -f $code)
}

function Get-KeyFullName([uint32]$code) {
    if ($HidCodeToItem.ContainsKey($code)) {
        return ("{0} [0x{1:X8}]" -f $HidCodeToItem[$code].Name, $code)
    }
    return ("カスタム [0x{0:X8}]" -f $code)
}

# UK版 (English UK / ISO) 実機写真に完全準拠した2Dキャンバス座標＆刻印定義 (全84キー, Canvas 960 x 404)
# Type: "FnRow" (上段小型), "Std" (標準UKキー), "EnterISO" (UK逆L字Enter), "Mod" (機能・修飾キー), "Half" (右下2段矢印/PgUp)

# --- 共通ファンクション列 (16キー, Y=10, H=36) ---
$CommonFnKeys = @(
    @{ Id="Esc";   Label="Esc";    Type="FnRow"; X=10;  Y=10; W=68; H=36; Col=0;  Row=5; TL="Esc";  BL="FnLock"; Icon="";    Sub="";   DuplicateCells=@() }
    @{ Id="F1";    Label="F1";     Type="FnRow"; X=90;  Y=10; W=50; H=36; Col=1;  Row=0; TL="";     BL="";       Icon="🔇";  Sub="F1"; DuplicateCells=@() }
    @{ Id="F2";    Label="F2";     Type="FnRow"; X=143; Y=10; W=50; H=36; Col=2;  Row=0; TL="";     BL="";       Icon="🔉-"; Sub="F2"; DuplicateCells=@() }
    @{ Id="F3";    Label="F3";     Type="FnRow"; X=196; Y=10; W=50; H=36; Col=2;  Row=3; TL="";     BL="";       Icon="🔊+"; Sub="F3"; DuplicateCells=@() }
    @{ Id="F4";    Label="F4";     Type="FnRow"; X=249; Y=10; W=50; H=36; Col=2;  Row=5; TL="";     BL="";       Icon="🎤×"; Sub="F4"; DuplicateCells=@() }

    @{ Id="F5";    Label="F5";     Type="FnRow"; X=310; Y=10; W=50; H=36; Col=8;  Row=5; TL="";     BL="";       Icon="☀-";  Sub="F5"; DuplicateCells=@() }
    @{ Id="F6";    Label="F6";     Type="FnRow"; X=363; Y=10; W=50; H=36; Col=5;  Row=5; TL="";     BL="";       Icon="☀+";  Sub="F6"; DuplicateCells=@() }
    @{ Id="F7";    Label="F7";     Type="FnRow"; X=416; Y=10; W=50; H=36; Col=6;  Row=3; TL="";     BL="";       Icon="🖥";  Sub="F7"; DuplicateCells=@() }
    @{ Id="F8";    Label="F8";     Type="FnRow"; X=469; Y=10; W=50; H=36; Col=6;  Row=0; TL="";     BL="";       Icon="📡";  Sub="F8"; DuplicateCells=@() }

    @{ Id="F9";    Label="F9";     Type="FnRow"; X=530; Y=10; W=50; H=36; Col=8;  Row=0; TL="";     BL="";       Icon="💬";  Sub="F9";  DuplicateCells=@() }
    @{ Id="F10";   Label="F10";    Type="FnRow"; X=583; Y=10; W=50; H=36; Col=8;  Row=1; TL="";     BL="";       Icon="📞";  Sub="F10"; DuplicateCells=@() }
    @{ Id="F11";   Label="F11";    Type="FnRow"; X=636; Y=10; W=50; H=36; Col=10; Row=1; TL="";     BL="";       Icon="☎";  Sub="F11"; DuplicateCells=@() }
    @{ Id="F12";   Label="F12";    Type="FnRow"; X=689; Y=10; W=50; H=36; Col=9;  Row=1; TL="";     BL="";       Icon="☆";  Sub="F12"; DuplicateCells=@() }

    @{ Id="Home";  Label="Home";   Type="FnRow"; X=750; Y=10; W=56; H=36; Col=12; Row=0; TL="";     BL="";       Icon="Home";   Sub="";       DuplicateCells=@() }
    @{ Id="End";   Label="End";    Type="FnRow"; X=809; Y=10; W=56; H=36; Col=12; Row=1; TL="";     BL="";       Icon="End";    Sub="Insert"; DuplicateCells=@() }
    @{ Id="Del";   Label="Delete"; Type="FnRow"; X=868; Y=10; W=82; H=36; Col=10; Row=0; TL="";     BL="";       Icon="Delete"; Sub="";       DuplicateCells=@() }
)

# --- 共通矢印・ナビゲーションキー (6キー: 右下2段) ---
$CommonNavKeys = @(
    @{ Id="PgUp";    Label="PgUp";          Type="Half"; X=754; Y=296; W=62;  H=31; Col=11; Row=0; Text="PgUp"; DuplicateCells=@() }
    @{ Id="Up";      Label="↑";             Type="Half"; X=821; Y=296; W=62;  H=31; Col=12; Row=5; Text="↑";    DuplicateCells=@() }
    @{ Id="PgDn";    Label="PgDn";          Type="Half"; X=888; Y=296; W=62;  H=31; Col=11; Row=1; Text="PgDn"; DuplicateCells=@() }
    @{ Id="Left";    Label="←";             Type="Half"; X=754; Y=331; W=62;  H=31; Col=12; Row=7; Text="←";    DuplicateCells=@() }
    @{ Id="Down";    Label="↓";             Type="Half"; X=821; Y=331; W=62;  H=31; Col=10; Row=7; Text="↓";    DuplicateCells=@() }
    @{ Id="Right";   Label="→";             Type="Half"; X=888; Y=331; W=62;  H=31; Col=9;  Row=7; Text="→";    DuplicateCells=@() }
)

# --- 1. 日本語 JIS (全88キー) 第2段〜第6段 ---
$Layout_JIS_Body = @(
    # 第2段: 数字列 (15キー)
    @{ Id="Hankaku"; Label="半角/全角";  Type="Std"; X=10;  Y=52; W=48; H=56; Col=0; Row=0; TL="半角"; TR="全角"; BL="漢字"; BR=""; DuplicateCells=@() }
    @{ Id="K1";      Label="1 (ぬ)";     Type="Std"; X=62;  Y=52; W=56; H=56; Col=0; Row=1; TL="!";  TR=""; BL="1"; BR="ぬ"; DuplicateCells=@() }
    @{ Id="K2";      Label='2 (ふ)';     Type="Std"; X=122; Y=52; W=56; H=56; Col=1; Row=1; TL='"';  TR=""; BL="2"; BR="ふ"; DuplicateCells=@() }
    @{ Id="K3";      Label="3 (あ)";     Type="Std"; X=182; Y=52; W=56; H=56; Col=2; Row=1; TL="#";  TR=""; BL="3"; BR="あ"; DuplicateCells=@() }
    @{ Id="K4";      Label="4 (う)";     Type="Std"; X=242; Y=52; W=56; H=56; Col=3; Row=1; TL="$";  TR=""; BL="4"; BR="う"; DuplicateCells=@() }
    @{ Id="K5";      Label="5 (え)";     Type="Std"; X=302; Y=52; W=56; H=56; Col=3; Row=0; TL="%";  TR=""; BL="5"; BR="え"; DuplicateCells=@() }
    @{ Id="K6";      Label="6 (お)";     Type="Std"; X=362; Y=52; W=56; H=56; Col=4; Row=0; TL="&";  TR=""; BL="6"; BR="お"; DuplicateCells=@() }
    @{ Id="K7";      Label="7 (や)";     Type="Std"; X=422; Y=52; W=56; H=56; Col=4; Row=1; TL="'";  TR=""; BL="7"; BR="や"; DuplicateCells=@() }
    @{ Id="K8";      Label="8 (ゆ)";     Type="Std"; X=482; Y=52; W=56; H=56; Col=5; Row=1; TL="(";  TR=""; BL="8"; BR="ゆ"; DuplicateCells=@() }
    @{ Id="K9";      Label="9 (よ)";     Type="Std"; X=542; Y=52; W=56; H=56; Col=6; Row=1; TL=")";  TR=""; BL="9"; BR="よ"; DuplicateCells=@() }
    @{ Id="K0";      Label="0 (わ)";     Type="Std"; X=602; Y=52; W=56; H=56; Col=7; Row=1; TL="";   TR=""; BL="0"; BR="わ"; DuplicateCells=@() }
    @{ Id="Minus";   Label="- (ほ)";     Type="Std"; X=662; Y=52; W=56; H=56; Col=7; Row=0; TL="=";  TR=""; BL="-"; BR="ほ"; DuplicateCells=@() }
    @{ Id="Caret";   Label="^ (へ)";     Type="Std"; X=722; Y=52; W=56; H=56; Col=5; Row=0; TL="~";  TR=""; BL="^"; BR="へ"; DuplicateCells=@() }
    @{ Id="Yen";     Label="¥ (|)";      Type="Std"; X=782; Y=52; W=56; H=56; Col=8; Row=2; TL="|";  TR=""; BL="¥"; BR="ー"; DuplicateCells=@() }
    @{ Id="BS";      Label="Backspace";  Type="Mod"; X=842; Y=52; W=108; H=56; Col=8; Row=3; TL="";  TR="⌫"; ML=""; BL=""; DuplicateCells=@() }

    # 第3段: QWERTY列 (13キー + JIS逆L字Enter)
    @{ Id="Tab";     Label="Tab";        Type="Mod";     X=10;  Y=113; W=66;  H=56; Col=0; Row=3; TL="Tab"; TR="⇥"; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="Q";       Label="Q (た)";     Type="Std";     X=80;  Y=113; W=56;  H=56; Col=0; Row=2; TL="Q"; TR=""; BL=""; BR="た"; DuplicateCells=@() }
    @{ Id="W";       Label="W (て)";     Type="Std";     X=140; Y=113; W=56;  H=56; Col=1; Row=2; TL="W"; TR=""; BL=""; BR="て"; DuplicateCells=@() }
    @{ Id="E";       Label="E (い)";     Type="Std";     X=200; Y=113; W=56;  H=56; Col=2; Row=2; TL="E"; TR=""; BL=""; BR="い"; DuplicateCells=@() }
    @{ Id="R";       Label="R (す)";     Type="Std";     X=260; Y=113; W=56;  H=56; Col=3; Row=2; TL="R"; TR=""; BL=""; BR="す"; DuplicateCells=@() }
    @{ Id="T";       Label="T (か)";     Type="Std";     X=320; Y=113; W=56;  H=56; Col=4; Row=2; TL="T"; TR=""; BL=""; BR="か"; DuplicateCells=@() }
    @{ Id="Y";       Label="Y (ん)";     Type="Std";     X=380; Y=113; W=56;  H=56; Col=4; Row=3; TL="Y"; TR=""; BL=""; BR="ん"; DuplicateCells=@() }
    @{ Id="U";       Label="U (な)";     Type="Std";     X=440; Y=113; W=56;  H=56; Col=3; Row=3; TL="U"; TR=""; BL=""; BR="な"; DuplicateCells=@() }
    @{ Id="I";       Label="I (に)";     Type="Std";     X=500; Y=113; W=56;  H=56; Col=5; Row=2; TL="I"; TR=""; BL=""; BR="に"; DuplicateCells=@() }
    @{ Id="O";       Label="O (ら)";     Type="Std";     X=560; Y=113; W=56;  H=56; Col=6; Row=2; TL="O"; TR=""; BL=""; BR="ら"; DuplicateCells=@() }
    @{ Id="P";       Label="P (せ)";     Type="Std";     X=620; Y=113; W=56;  H=56; Col=7; Row=2; TL="P"; TR=""; BL=""; BR="せ"; DuplicateCells=@() }
    @{ Id="At";      Label="@ (゛)";     Type="Std";     X=680; Y=113; W=56;  H=56; Col=7; Row=3; TL="``"; TR=""; BL="@"; BR="゛"; DuplicateCells=@() }
    @{ Id="LBracket";Label="[ (゜)";     Type="Std";     X=740; Y=113; W=56;  H=56; Col=5; Row=3; TL="{"; TR=""; BL="["; BR="゜"; DuplicateCells=@() }
    @{ Id="Enter";   Label="Enter";      Type="EnterISO"; X=800; Y=113; W=150; H=117; NotchW=14; NotchH=58; Col=8; Row=6; TL=""; TR=""; ML=""; BL=""; Text="Enter"; DuplicateCells=@() }

    # 第4段: ASDF列 (12キー)
    @{ Id="Caps";    Label="CapsLock";   Type="Mod"; X=10;  Y=174; W=80; H=56; Col=1; Row=3; TL="Caps"; TR=""; ML="英数"; BL=""; DuplicateCells=@() }
    @{ Id="A";       Label="A (ち)";     Type="Std"; X=94;  Y=174; W=56; H=56; Col=0; Row=4; TL="A"; TR=""; BL=""; BR="ち"; DuplicateCells=@() }
    @{ Id="S";       Label="S (と)";     Type="Std"; X=154; Y=174; W=56; H=56; Col=1; Row=4; TL="S"; TR=""; BL=""; BR="と"; DuplicateCells=@() }
    @{ Id="D";       Label="D (し)";     Type="Std"; X=214; Y=174; W=56; H=56; Col=2; Row=4; TL="D"; TR=""; BL=""; BR="し"; DuplicateCells=@() }
    @{ Id="F";       Label="F (は)";     Type="Std"; X=274; Y=174; W=56; H=56; Col=3; Row=4; TL="F"; TR=""; BL=""; BR="は"; DuplicateCells=@() }
    @{ Id="G";       Label="G (き)";     Type="Std"; X=334; Y=174; W=56; H=56; Col=3; Row=5; TL="G"; TR=""; BL=""; BR="き"; DuplicateCells=@() }
    @{ Id="H";       Label="H (ま)";     Type="Std"; X=394; Y=174; W=56; H=56; Col=4; Row=5; TL="H"; TR=""; BL=""; BR="ま"; DuplicateCells=@() }
    @{ Id="J";       Label="J (ま)";     Type="Std"; X=454; Y=174; W=56; H=56; Col=4; Row=4; TL="J"; TR=""; BL=""; BR="ま"; DuplicateCells=@() }
    @{ Id="K";       Label="K (の)";     Type="Std"; X=514; Y=174; W=56; H=56; Col=5; Row=4; TL="K"; TR=""; BL=""; BR="の"; DuplicateCells=@() }
    @{ Id="L";       Label="L (り)";     Type="Std"; X=574; Y=174; W=56; H=56; Col=6; Row=4; TL="L"; TR=""; BL=""; BR="り"; DuplicateCells=@() }
    @{ Id="Semicolon";Label="; (れ)";    Type="Std"; X=634; Y=174; W=56; H=56; Col=7; Row=4; TL="+"; TR=""; BL=";"; BR="れ"; DuplicateCells=@() }
    @{ Id="Colon";   Label=": (け)";     Type="Std"; X=694; Y=174; W=56; H=56; Col=7; Row=5; TL="*"; TR=""; BL=":"; BR="け"; DuplicateCells=@() }
    @{ Id="RBracket";Label="] (む)";     Type="Std"; X=754; Y=174; W=56; H=56; Col=7; Row=6; TL="}"; TR=""; BL="]"; BR="む"; DuplicateCells=@() }

    # 第5段: ZXCV列 (12キー)
    @{ Id="LShift";  Label="左Shift";    Type="Mod"; X=10;  Y=235; W=94;  H=56; Col=14; Row=3; TL="⇧"; TR=""; ML="Shift"; BL=""; DuplicateCells=@() }
    @{ Id="Z";       Label="Z (つ)";     Type="Std"; X=108; Y=235; W=56;  H=56; Col=0;  Row=6; TL="Z"; TR=""; BL=""; BR="つ"; DuplicateCells=@() }
    @{ Id="X";       Label="X (さ)";     Type="Std"; X=168; Y=235; W=56;  H=56; Col=1;  Row=6; TL="X"; TR=""; BL=""; BR="さ"; DuplicateCells=@() }
    @{ Id="C";       Label="C (そ)";     Type="Std"; X=228; Y=235; W=56;  H=56; Col=2;  Row=6; TL="C"; TR=""; BL=""; BR="そ"; DuplicateCells=@() }
    @{ Id="V";       Label="V (ひ)";     Type="Std"; X=288; Y=235; W=56;  H=56; Col=3;  Row=6; TL="V"; TR=""; BL=""; BR="ひ"; DuplicateCells=@() }
    @{ Id="B";       Label="B (こ)";     Type="Std"; X=348; Y=235; W=56;  H=56; Col=3;  Row=7; TL="B"; TR=""; BL=""; BR="こ"; DuplicateCells=@() }
    @{ Id="N";       Label="N (み)";     Type="Std"; X=408; Y=235; W=56;  H=56; Col=4;  Row=7; TL="N"; TR=""; BL=""; BR="み"; DuplicateCells=@() }
    @{ Id="M";       Label="M (も)";     Type="Std"; X=468; Y=235; W=56;  H=56; Col=4;  Row=6; TL="M"; TR=""; BL=""; BR="も"; DuplicateCells=@() }
    @{ Id="Comma";   Label=", (ね)";     Type="Std"; X=528; Y=235; W=56;  H=56; Col=5;  Row=6; TL="<"; TR=""; BL=","; BR="ね"; DuplicateCells=@() }
    @{ Id="Period";  Label=". (る)";     Type="Std"; X=588; Y=235; W=56;  H=56; Col=6;  Row=6; TL=">"; TR=""; BL="."; BR="る"; DuplicateCells=@() }
    @{ Id="Slash";   Label="/ (め)";     Type="Std"; X=648; Y=235; W=56;  H=56; Col=7;  Row=7; TL="?"; TR=""; BL="/"; BR="め"; DuplicateCells=@() }
    @{ Id="BackslashRo";Label="＼ (ろ)"; Type="Std"; X=708; Y=235; W=56;  H=56; Col=5;  Row=7; TL="_"; TR=""; BL="＼"; BR="ろ"; DuplicateCells=@() }
    @{ Id="RShift";  Label="右Shift";    Type="Mod"; X=768; Y=235; W=182; H=56; Col=14; Row=6; TL=""; TR="⇧"; ML="Shift"; BL=""; DuplicateCells=@() }

    # 第6段: 最下段 (11キー)
    @{ Id="Fn";      Label="Fn";         Type="Mod"; X=10;  Y=296; W=48; H=58; Col=1;  Row=7; TL="Fn";   TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="LCtrl";   Label="左Ctrl";     Type="Mod"; X=62;  Y=296; W=54; H=58; Col=15; Row=0; TL="Ctrl"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="LWin";    Label="Win";        Type="Mod"; X=120; Y=296; W=48; H=58; Col=9;  Row=3; TL="";     TR=""; ML="⊞"; BL=""; DuplicateCells=@(@{Col=12;Row=3}) }
    @{ Id="LAlt";    Label="左Alt";      Type="Mod"; X=172; Y=296; W=48; H=58; Col=13; Row=5; TL="Alt";  TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="Muhenkan";Label="無変換";     Type="Mod"; X=224; Y=296; W=48; H=58; Col=0;  Row=7; TL="無変換"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="Space";   Label="Space";      Type="Mod"; X=276; Y=296; W=176; H=58; Col=8; Row=7; TL="";     TR=""; ML=""; BL="☀"; DuplicateCells=@() }
    @{ Id="Henkan";  Label="変換";       Type="Mod"; X=456; Y=296; W=48; H=58; Col=6;  Row=5; TL="変換"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="Kana";    Label="カタカナひらがな"; Type="Mod"; X=508; Y=296; W=56; H=58; Col=6;  Row=7; TL="かな"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="RAlt";    Label="右Alt";      Type="Mod"; X=568; Y=296; W=48; H=58; Col=13; Row=7; TL="Alt";  TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="PrtSc";   Label="PrtSc";      Type="Mod"; X=620; Y=296; W=48; H=58; Col=13; Row=1; TL="PrtSc"; TR=""; ML=""; BL="✂"; DuplicateCells=@(@{Col=12;Row=6}) }
    @{ Id="RCtrl";   Label="右Ctrl";     Type="Mod"; X=672; Y=296; W=76; H=58; Col=15; Row=6; TL="Ctrl"; TR=""; ML=""; BL=""; DuplicateCells=@() }
)

# --- 2. 英語 UK (全84キー) 第2段〜第6段 ---
$Layout_UK_Body = @(
    # 第2段: 数字列 (14キー)
    @{ Id="Grave"; Label="`` ¬ ¦";    Type="Std"; X=10;  Y=52; W=48;  H=56; Col=0; Row=0; TL="¬"; TR=""; BL="``"; BR="¦"; DuplicateCells=@() }
    @{ Id="K1";    Label="1 (!)";     Type="Std"; X=62;  Y=52; W=62;  H=56; Col=0; Row=1; TL="!"; TR=""; BL="1";  BR="";  DuplicateCells=@() }
    @{ Id="K2";    Label='2 (")';     Type="Std"; X=128; Y=52; W=62;  H=56; Col=1; Row=1; TL='"'; TR=""; BL="2";  BR="";  DuplicateCells=@() }
    @{ Id="K3";    Label="3 (£)";     Type="Std"; X=194; Y=52; W=62;  H=56; Col=2; Row=1; TL="£"; TR=""; BL="3";  BR="";  DuplicateCells=@() }
    @{ Id="K4";    Label="4 ($ €)";   Type="Std"; X=260; Y=52; W=62;  H=56; Col=3; Row=1; TL="$"; TR=""; BL="4";  BR="€"; DuplicateCells=@() }
    @{ Id="K5";    Label="5 (%)";     Type="Std"; X=326; Y=52; W=62;  H=56; Col=3; Row=0; TL="%"; TR=""; BL="5";  BR="";  DuplicateCells=@() }
    @{ Id="K6";    Label="6 (^)";     Type="Std"; X=392; Y=52; W=62;  H=56; Col=4; Row=0; TL="^"; TR=""; BL="6";  BR="";  DuplicateCells=@() }
    @{ Id="K7";    Label="7 (&)";     Type="Std"; X=458; Y=52; W=62;  H=56; Col=4; Row=1; TL="&"; TR=""; BL="7";  BR="";  DuplicateCells=@() }
    @{ Id="K8";    Label="8 (*)";     Type="Std"; X=524; Y=52; W=62;  H=56; Col=5; Row=1; TL="*"; TR=""; BL="8";  BR="";  DuplicateCells=@() }
    @{ Id="K9";    Label="9 (()";     Type="Std"; X=590; Y=52; W=62;  H=56; Col=6; Row=1; TL="("; TR=""; BL="9";  BR="";  DuplicateCells=@() }
    @{ Id="K0";    Label="0 ())";     Type="Std"; X=656; Y=52; W=62;  H=56; Col=7; Row=1; TL=")"; TR=""; BL="0";  BR="";  DuplicateCells=@() }
    @{ Id="Minus"; Label="- (_)";     Type="Std"; X=722; Y=52; W=56;  H=56; Col=7; Row=0; TL="—"; TR=""; BL="-";  BR="";  DuplicateCells=@() }
    @{ Id="Equal"; Label="= (+)";     Type="Std"; X=782; Y=52; W=56;  H=56; Col=5; Row=0; TL="+"; TR=""; BL="=";  BR="";  DuplicateCells=@() }
    @{ Id="BS";    Label="Backspace"; Type="Mod"; X=842; Y=52; W=108; H=56; Col=8; Row=3; TL="";  TR="⌫"; ML="";  BL="";  DuplicateCells=@() }

    # 第3段: QWERTY列 (13キー + UK逆L字Enter)
    @{ Id="Tab";   Label="Tab";        Type="Mod";     X=10;  Y=113; W=74;  H=56; Col=0; Row=3; TL="Tab"; TR="⇥"; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="Q";     Label="Q";          Type="Std";     X=88;  Y=113; W=62;  H=56; Col=0; Row=2; TL="Q"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="W";     Label="W";          Type="Std";     X=154; Y=113; W=62;  H=56; Col=1; Row=2; TL="W"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="E";     Label="E (€)";      Type="Std";     X=220; Y=113; W=62;  H=56; Col=2; Row=2; TL="E"; TR=""; BL="";  BR="€"; DuplicateCells=@() }
    @{ Id="R";     Label="R";          Type="Std";     X=286; Y=113; W=62;  H=56; Col=3; Row=2; TL="R"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="T";     Label="T";          Type="Std";     X=352; Y=113; W=62;  H=56; Col=4; Row=2; TL="T"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="Y";     Label="Y";          Type="Std";     X=418; Y=113; W=62;  H=56; Col=4; Row=3; TL="Y"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="U";     Label="U";          Type="Std";     X=484; Y=113; W=62;  H=56; Col=3; Row=3; TL="U"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="I";     Label="I";          Type="Std";     X=550; Y=113; W=62;  H=56; Col=5; Row=2; TL="I"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="O";     Label="O";          Type="Std";     X=616; Y=113; W=62;  H=56; Col=6; Row=2; TL="O"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="P";     Label="P";          Type="Std";     X=682; Y=113; W=62;  H=56; Col=7; Row=2; TL="P"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="LBracket"; Label="[ ({)";   Type="Std";     X=748; Y=113; W=56;  H=56; Col=7; Row=3; TL="{"; TR=""; BL="[";  BR=""; DuplicateCells=@() }
    @{ Id="RBracket"; Label="] (})";   Type="Std";     X=808; Y=113; W=54;  H=56; Col=5; Row=3; TL="}"; TR=""; BL="]";  BR=""; DuplicateCells=@() }
    @{ Id="Enter";    Label="Enter";   Type="EnterISO"; X=866; Y=113; W=84;  H=117; NotchW=16; NotchH=58; Col=8; Row=6; TL=""; TR=""; ML=""; BL=""; Text="↵"; DuplicateCells=@() }

    # 第4段: ASDF列 (12キー)
    @{ Id="Caps";  Label="CapsLock";   Type="Mod"; X=10;  Y=174; W=84; H=56; Col=1; Row=3; TL="Caps"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="A";     Label="A";          Type="Std"; X=98;  Y=174; W=62; H=56; Col=0; Row=4; TL="A"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="S";     Label="S";          Type="Std"; X=164; Y=174; W=62; H=56; Col=1; Row=4; TL="S"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="D";     Label="D";          Type="Std"; X=230; Y=174; W=62; H=56; Col=2; Row=4; TL="D"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="F";     Label="F";          Type="Std"; X=296; Y=174; W=62; H=56; Col=3; Row=4; TL="F"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="G";     Label="G";          Type="Std"; X=362; Y=174; W=62; H=56; Col=3; Row=5; TL="G"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="H";     Label="H";          Type="Std"; X=428; Y=174; W=62; H=56; Col=4; Row=5; TL="H"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="J";     Label="J";          Type="Std"; X=494; Y=174; W=62; H=56; Col=4; Row=4; TL="J"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="K";     Label="K";          Type="Std"; X=560; Y=174; W=62; H=56; Col=5; Row=4; TL="K"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="L";     Label="L";          Type="Std"; X=626; Y=174; W=62; H=56; Col=6; Row=4; TL="L"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="Semicolon";Label="; (:)";   Type="Std"; X=692; Y=174; W=56; H=56; Col=7; Row=4; TL=":"; TR=""; BL=";";  BR=""; DuplicateCells=@() }
    @{ Id="Quote";    Label="' (@)";   Type="Std"; X=752; Y=174; W=56; H=56; Col=7; Row=5; TL="@"; TR=""; BL="'";  BR=""; DuplicateCells=@() }
    @{ Id="Hash";     Label="# (~)";   Type="Std"; X=812; Y=174; W=66; H=56; Col=7; Row=6; TL="~"; TR=""; BL="#";  BR=""; DuplicateCells=@() }

    # 第5段: ZXCV列 (13キー)
    @{ Id="LShift";  Label="左Shift";       Type="Mod"; X=10;  Y=235; W=66;  H=56; Col=14; Row=3; TL="⇧"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="IsoBS";   Label="＼ (|) [ISO]";  Type="Std"; X=80;  Y=235; W=58;  H=56; Col=1;  Row=5; TL="|"; TR=""; BL="＼"; BR=""; DuplicateCells=@() }
    @{ Id="Z";       Label="Z";             Type="Std"; X=142; Y=235; W=62;  H=56; Col=0;  Row=6; TL="Z"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="X";       Label="X";             Type="Std"; X=208; Y=235; W=62;  H=56; Col=1;  Row=6; TL="X"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="C";       Label="C";             Type="Std"; X=274; Y=235; W=62;  H=56; Col=2;  Row=6; TL="C"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="V";       Label="V";             Type="Std"; X=340; Y=235; W=62;  H=56; Col=3;  Row=6; TL="V"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="B";       Label="B";             Type="Std"; X=406; Y=235; W=62;  H=56; Col=3;  Row=7; TL="B"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="N";       Label="N";             Type="Std"; X=472; Y=235; W=62;  H=56; Col=4;  Row=7; TL="N"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="M";       Label="M";             Type="Std"; X=538; Y=235; W=62;  H=56; Col=4;  Row=6; TL="M"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="Comma";   Label=", (<)";         Type="Std"; X=604; Y=235; W=62;  H=56; Col=5;  Row=6; TL="<"; TR=""; BL=","; BR=""; DuplicateCells=@() }
    @{ Id="Period";  Label=". (>)";         Type="Std"; X=670; Y=235; W=62;  H=56; Col=6;  Row=6; TL=">"; TR=""; BL="."; BR=""; DuplicateCells=@() }
    @{ Id="Slash";   Label="/ (?)";         Type="Std"; X=736; Y=235; W=58;  H=56; Col=7;  Row=7; TL="?"; TR=""; BL="/"; BR=""; DuplicateCells=@() }
    @{ Id="RShift";  Label="右Shift";       Type="Mod"; X=798; Y=235; W=152; H=56; Col=14; Row=6; TL="";  TR="⇧"; ML=""; BL=""; DuplicateCells=@() }

    # 第6段: 最下段 (8キー)
    @{ Id="Fn";      Label="Fn";            Type="Mod"; X=10;  Y=296; W=54;  H=58; Col=1;  Row=7; TL="Fn";    TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="LCtrl";   Label="左Ctrl";        Type="Mod"; X=68;  Y=296; W=68;  H=58; Col=15; Row=0; TL="Ctrl";  TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="LWin";    Label="Win";           Type="Mod"; X=140; Y=296; W=58;  H=58; Col=9;  Row=3; TL="";      TR=""; ML="⊞"; BL="";  DuplicateCells=@(@{Col=12;Row=3}) }
    @{ Id="LAlt";    Label="左Alt";         Type="Mod"; X=202; Y=296; W=58;  H=58; Col=13; Row=5; TL="Alt";   TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="Space";   Label="Space";         Type="Mod"; X=264; Y=296; W=312; H=58; Col=8;  Row=7; TL="";      TR=""; ML="";  BL="☀"; DuplicateCells=@() }
    @{ Id="RAlt";    Label="AltGr (右Alt)"; Type="Mod"; X=580; Y=296; W=54;  H=58; Col=13; Row=7; TL="AltGr"; TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="PrtSc";   Label="PrtSc";         Type="Mod"; X=638; Y=296; W=54;  H=58; Col=13; Row=1; TL="PrtSc"; TR=""; ML="";  BL="✂"; DuplicateCells=@(@{Col=12;Row=6}) }
    @{ Id="RCtrl";   Label="右Ctrl";        Type="Mod"; X=696; Y=296; W=54;  H=58; Col=15; Row=6; TL="Ctrl";  TR=""; ML="";  BL="";  DuplicateCells=@() }
)

# --- 3. 英語 US (全83キー) 第2段〜第6段 ---
$Layout_US_Body = @(
    # 第2段: 数字列 (14キー)
    @{ Id="Grave";   Label="`` ~";       Type="Std"; X=10;  Y=52; W=48;  H=56; Col=0; Row=0; TL="~"; TR=""; BL="``"; BR=""; DuplicateCells=@() }
    @{ Id="K1";      Label="1 (!)";      Type="Std"; X=62;  Y=52; W=62;  H=56; Col=0; Row=1; TL="!"; TR=""; BL="1";  BR=""; DuplicateCells=@() }
    @{ Id="K2";      Label="2 (@)";      Type="Std"; X=128; Y=52; W=62;  H=56; Col=1; Row=1; TL="@"; TR=""; BL="2";  BR=""; DuplicateCells=@() }
    @{ Id="K3";      Label="3 (#)";      Type="Std"; X=194; Y=52; W=62;  H=56; Col=2; Row=1; TL="#"; TR=""; BL="3";  BR=""; DuplicateCells=@() }
    @{ Id="K4";      Label="4 ($ €)";    Type="Std"; X=260; Y=52; W=62;  H=56; Col=3; Row=1; TL="$"; TR=""; BL="4";  BR="€"; DuplicateCells=@() }
    @{ Id="K5";      Label="5 (%)";      Type="Std"; X=326; Y=52; W=62;  H=56; Col=3; Row=0; TL="%"; TR=""; BL="5";  BR=""; DuplicateCells=@() }
    @{ Id="K6";      Label="6 (^)";      Type="Std"; X=392; Y=52; W=62;  H=56; Col=4; Row=0; TL="^"; TR=""; BL="6";  BR=""; DuplicateCells=@() }
    @{ Id="K7";      Label="7 (&)";      Type="Std"; X=458; Y=52; W=62;  H=56; Col=4; Row=1; TL="&"; TR=""; BL="7";  BR=""; DuplicateCells=@() }
    @{ Id="K8";      Label="8 (*)";      Type="Std"; X=524; Y=52; W=62;  H=56; Col=5; Row=1; TL="*"; TR=""; BL="8";  BR=""; DuplicateCells=@() }
    @{ Id="K9";      Label="9 (()";      Type="Std"; X=590; Y=52; W=62;  H=56; Col=6; Row=1; TL="("; TR=""; BL="9";  BR=""; DuplicateCells=@() }
    @{ Id="K0";      Label="0 ())";      Type="Std"; X=656; Y=52; W=62;  H=56; Col=7; Row=1; TL=")"; TR=""; BL="0";  BR=""; DuplicateCells=@() }
    @{ Id="Minus";   Label="- (_)";      Type="Std"; X=722; Y=52; W=56;  H=56; Col=7; Row=0; TL="_"; TR=""; BL="-";  BR=""; DuplicateCells=@() }
    @{ Id="Equal";   Label="= (+)";      Type="Std"; X=782; Y=52; W=56;  H=56; Col=5; Row=0; TL="+"; TR=""; BL="=";  BR=""; DuplicateCells=@() }
    @{ Id="BS";      Label="Backspace";  Type="Mod"; X=842; Y=52; W=108; H=56; Col=8; Row=3; TL="";  TR="⌫"; ML=""; BL=""; DuplicateCells=@() }

    # 第3段: QWERTY列 (14キー: 右端に US Backslash [ \ | ])
    @{ Id="Tab";     Label="Tab";        Type="Mod"; X=10;  Y=113; W=74;  H=56; Col=0; Row=3; TL="Tab"; TR="⇥"; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="Q";       Label="Q";          Type="Std"; X=88;  Y=113; W=58;  H=56; Col=0; Row=2; TL="Q"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="W";       Label="W";          Type="Std"; X=150; Y=113; W=58;  H=56; Col=1; Row=2; TL="W"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="E";       Label="E";          Type="Std"; X=212; Y=113; W=58;  H=56; Col=2; Row=2; TL="E"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="R";       Label="R";          Type="Std"; X=274; Y=113; W=58;  H=56; Col=3; Row=2; TL="R"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="T";       Label="T";          Type="Std"; X=336; Y=113; W=58;  H=56; Col=4; Row=2; TL="T"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="Y";       Label="Y";          Type="Std"; X=398; Y=113; W=58;  H=56; Col=4; Row=3; TL="Y"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="U";       Label="U";          Type="Std"; X=460; Y=113; W=58;  H=56; Col=3; Row=3; TL="U"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="I";       Label="I";          Type="Std"; X=522; Y=113; W=58;  H=56; Col=5; Row=2; TL="I"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="O";       Label="O";          Type="Std"; X=584; Y=113; W=58;  H=56; Col=6; Row=2; TL="O"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="P";       Label="P";          Type="Std"; X=646; Y=113; W=58;  H=56; Col=7; Row=2; TL="P"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="LBracket";Label="[ ({)";      Type="Std"; X=708; Y=113; W=58;  H=56; Col=7; Row=3; TL="{"; TR=""; BL="[";  BR=""; DuplicateCells=@() }
    @{ Id="RBracket";Label="] (})";      Type="Std"; X=770; Y=113; W=58;  H=56; Col=5; Row=3; TL="}"; TR=""; BL="]";  BR=""; DuplicateCells=@() }
    @{ Id="USBackslash"; Label="＼ (|) [US]"; Type="Std"; X=832; Y=113; W=118; H=56; Col=8; Row=4; TL="|"; TR=""; BL="＼"; BR=""; DuplicateCells=@() }

    # 第4段: ASDF列 (12キー: 右端に横長ストレートEnter)
    @{ Id="Caps";    Label="CapsLock";   Type="Mod"; X=10;  Y=174; W=88;  H=56; Col=1; Row=3; TL="Caps"; TR=""; ML=""; BL=""; DuplicateCells=@() }
    @{ Id="A";       Label="A";          Type="Std"; X=102; Y=174; W=58;  H=56; Col=0; Row=4; TL="A"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="S";       Label="S";          Type="Std"; X=164; Y=174; W=58;  H=56; Col=1; Row=4; TL="S"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="D";       Label="D";          Type="Std"; X=226; Y=174; W=58;  H=56; Col=2; Row=4; TL="D"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="F";       Label="F";          Type="Std"; X=288; Y=174; W=58;  H=56; Col=3; Row=4; TL="F"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="G";       Label="G";          Type="Std"; X=350; Y=174; W=58;  H=56; Col=3; Row=5; TL="G"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="H";       Label="H";          Type="Std"; X=412; Y=174; W=58;  H=56; Col=4; Row=5; TL="H"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="J";       Label="J";          Type="Std"; X=474; Y=174; W=58;  H=56; Col=4; Row=4; TL="J"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="K";       Label="K";          Type="Std"; X=536; Y=174; W=58;  H=56; Col=5; Row=4; TL="K"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="L";       Label="L";          Type="Std"; X=598; Y=174; W=58;  H=56; Col=6; Row=4; TL="L"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="Semicolon";Label="; (:)";     Type="Std"; X=660; Y=174; W=58;  H=56; Col=7; Row=4; TL=":"; TR=""; BL=";";  BR=""; DuplicateCells=@() }
    @{ Id="Quote";   Label="Quote (' `")"; Type="Std"; X=722; Y=174; W=58; H=56; Col=7; Row=5; TL='"'; TR=""; BL="'";  BR=""; DuplicateCells=@() }
    @{ Id="Enter";   Label="Enter";      Type="Mod"; X=784; Y=174; W=166; H=56; Col=8; Row=6; TL="";  TR="↵"; ML="Enter"; BL=""; DuplicateCells=@() }

    # 第5段: ZXCV列 (12キー: 横長左Shift ＆ 横長右Shift)
    @{ Id="LShift";  Label="左Shift";    Type="Mod"; X=10;  Y=235; W=118; H=56; Col=14; Row=3; TL="⇧"; TR=""; ML="Shift"; BL=""; DuplicateCells=@() }
    @{ Id="Z";       Label="Z";          Type="Std"; X=132; Y=235; W=58;  H=56; Col=0;  Row=6; TL="Z"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="X";       Label="X";          Type="Std"; X=194; Y=235; W=58;  H=56; Col=1;  Row=6; TL="X"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="C";       Label="C";          Type="Std"; X=256; Y=235; W=58;  H=56; Col=2;  Row=6; TL="C"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="V";       Label="V";          Type="Std"; X=318; Y=235; W=58;  H=56; Col=3;  Row=6; TL="V"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="B";       Label="B";          Type="Std"; X=380; Y=235; W=58;  H=56; Col=3;  Row=7; TL="B"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="N";       Label="N";          Type="Std"; X=442; Y=235; W=58;  H=56; Col=4;  Row=7; TL="N"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="M";       Label="M";          Type="Std"; X=504; Y=235; W=58;  H=56; Col=4;  Row=6; TL="M"; TR=""; BL="";  BR=""; DuplicateCells=@() }
    @{ Id="Comma";   Label=", (<)";      Type="Std"; X=566; Y=235; W=58;  H=56; Col=5;  Row=6; TL="<"; TR=""; BL=","; BR=""; DuplicateCells=@() }
    @{ Id="Period";  Label=". (>)";      Type="Std"; X=628; Y=235; W=58;  H=56; Col=6;  Row=6; TL=">"; TR=""; BL="."; BR=""; DuplicateCells=@() }
    @{ Id="Slash";   Label="/ (?)";      Type="Std"; X=690; Y=235; W=58;  H=56; Col=7;  Row=7; TL="?"; TR=""; BL="/"; BR=""; DuplicateCells=@() }
    @{ Id="RShift";  Label="右Shift";    Type="Mod"; X=752; Y=235; W=198; H=56; Col=14; Row=6; TL="";  TR="⇧"; ML="Shift"; BL=""; DuplicateCells=@() }

    # 第6段: 最下段 (8キー: ロングスペースバー)
    @{ Id="Fn";      Label="Fn";            Type="Mod"; X=10;  Y=296; W=54;  H=58; Col=1;  Row=7; TL="Fn";    TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="LCtrl";   Label="左Ctrl";        Type="Mod"; X=68;  Y=296; W=68;  H=58; Col=15; Row=0; TL="Ctrl";  TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="LWin";    Label="Win";           Type="Mod"; X=140; Y=296; W=58;  H=58; Col=9;  Row=3; TL="";      TR=""; ML="⊞"; BL="";  DuplicateCells=@(@{Col=12;Row=3}) }
    @{ Id="LAlt";    Label="左Alt";         Type="Mod"; X=202; Y=296; W=58;  H=58; Col=13; Row=5; TL="Alt";   TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="Space";   Label="Space";         Type="Mod"; X=264; Y=296; W=312; H=58; Col=8;  Row=7; TL="";      TR=""; ML="";  BL="☀"; DuplicateCells=@() }
    @{ Id="RAlt";    Label="Alt (右Alt)";   Type="Mod"; X=580; Y=296; W=54;  H=58; Col=13; Row=7; TL="Alt";   TR=""; ML="";  BL="";  DuplicateCells=@() }
    @{ Id="PrtSc";   Label="PrtSc";         Type="Mod"; X=638; Y=296; W=54;  H=58; Col=13; Row=1; TL="PrtSc"; TR=""; ML="";  BL="✂"; DuplicateCells=@(@{Col=12;Row=6}) }
    @{ Id="RCtrl";   Label="右Ctrl";        Type="Mod"; X=696; Y=296; W=54;  H=58; Col=15; Row=6; TL="Ctrl";  TR=""; ML="";  BL="";  DuplicateCells=@() }
)

# --- 4. フランス語 FR / AZERTY (全84キー) ---
$Layout_FR_FnKeys = @(
    @{Id='Esc'; Label='Échap'; Type='FnRow'; X=10; Y=10; W=68; H=36; Col=0; Row=5; TL='Échap'; BL='FnLock'; Icon=''; Sub=''; DuplicateCells=@()}
    @{Id='F1'; Label='F1'; Type='FnRow'; X=90; Y=10; W=50; H=36; Col=1; Row=0; TL=''; BL=''; Icon='🔇'; Sub='F1'; DuplicateCells=@()}
    @{Id='F2'; Label='F2'; Type='FnRow'; X=143; Y=10; W=50; H=36; Col=2; Row=0; TL=''; BL=''; Icon='🔉-'; Sub='F2'; DuplicateCells=@()}
    @{Id='F3'; Label='F3'; Type='FnRow'; X=196; Y=10; W=50; H=36; Col=2; Row=3; TL=''; BL=''; Icon='🔊+'; Sub='F3'; DuplicateCells=@()}
    @{Id='F4'; Label='F4'; Type='FnRow'; X=249; Y=10; W=50; H=36; Col=2; Row=5; TL=''; BL=''; Icon='🎤×'; Sub='F4'; DuplicateCells=@()}
    @{Id='F5'; Label='F5'; Type='FnRow'; X=310; Y=10; W=50; H=36; Col=8; Row=5; TL=''; BL=''; Icon='☀-'; Sub='F5'; DuplicateCells=@()}
    @{Id='F6'; Label='F6'; Type='FnRow'; X=363; Y=10; W=50; H=36; Col=5; Row=5; TL=''; BL=''; Icon='☀+'; Sub='F6'; DuplicateCells=@()}
    @{Id='F7'; Label='F7'; Type='FnRow'; X=416; Y=10; W=50; H=36; Col=6; Row=3; TL=''; BL=''; Icon='🖥'; Sub='F7'; DuplicateCells=@()}
    @{Id='F8'; Label='F8'; Type='FnRow'; X=469; Y=10; W=50; H=36; Col=6; Row=0; TL=''; BL=''; Icon='📡'; Sub='F8'; DuplicateCells=@()}
    @{Id='F9'; Label='F9'; Type='FnRow'; X=530; Y=10; W=50; H=36; Col=8; Row=0; TL=''; BL=''; Icon='💬'; Sub='F9'; DuplicateCells=@()}
    @{Id='F10'; Label='F10'; Type='FnRow'; X=583; Y=10; W=50; H=36; Col=8; Row=1; TL=''; BL=''; Icon='📞'; Sub='F10'; DuplicateCells=@()}
    @{Id='F11'; Label='F11'; Type='FnRow'; X=636; Y=10; W=50; H=36; Col=10; Row=1; TL=''; BL=''; Icon='☎'; Sub='F11'; DuplicateCells=@()}
    @{Id='F12'; Label='F12'; Type='FnRow'; X=689; Y=10; W=50; H=36; Col=9; Row=1; TL=''; BL=''; Icon='☆'; Sub='F12'; DuplicateCells=@()}
    @{Id='Home'; Label='↖ (Home)'; Type='FnRow'; X=750; Y=10; W=56; H=36; Col=12; Row=0; TL='↖'; BL=''; Icon='Home'; Sub=''; DuplicateCells=@()}
    @{Id='End'; Label='Fin (End)'; Type='FnRow'; X=809; Y=10; W=56; H=36; Col=12; Row=1; TL='Fin'; BL='Inser'; Icon='End'; Sub='Inser'; DuplicateCells=@()}
    @{Id='Del'; Label='Suppr'; Type='FnRow'; X=868; Y=10; W=82; H=36; Col=10; Row=0; TL='Suppr'; BL=''; Icon='Delete'; Sub=''; DuplicateCells=@()}
)

$Layout_FR_Body = @(
    @{Id='Square'; Label='²'; Type='Std'; X=10; Y=52; W=48; H=56; Col=0; Row=0; TL='²'; TR=''; BL=''; BR='¦'; Sub=''; DuplicateCells=@()}
    @{Id='K1'; Label='1 (&)'; Type='Std'; X=62; Y=52; W=62; H=56; Col=0; Row=1; TL='1'; TR=''; BL='&'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='K2'; Label='2 (é ~)'; Type='Std'; X=128; Y=52; W=62; H=56; Col=1; Row=1; TL='2'; TR=''; BL='é'; BR=''; Sub='~'; DuplicateCells=@()}
    @{Id='K3'; Label='3 (" #)'; Type='Std'; X=194; Y=52; W=62; H=56; Col=2; Row=1; TL='3'; TR=''; BL='"'; BR=''; Sub='#'; DuplicateCells=@()}
    @{Id='K4'; Label='4 ('' {)'; Type='Std'; X=260; Y=52; W=62; H=56; Col=3; Row=1; TL='4'; TR=''; BL=''''; BR='€'; Sub='{'; DuplicateCells=@()}
    @{Id='K5'; Label='5 ( ( [ )'; Type='Std'; X=326; Y=52; W=62; H=56; Col=3; Row=0; TL='5'; TR=''; BL='('; BR=''; Sub='['; DuplicateCells=@()}
    @{Id='K6'; Label='6 (- |)'; Type='Std'; X=392; Y=52; W=62; H=56; Col=4; Row=0; TL='6'; TR=''; BL='-'; BR=''; Sub='|'; DuplicateCells=@()}
    @{Id='K7'; Label='7 (è `)'; Type='Std'; X=458; Y=52; W=62; H=56; Col=4; Row=1; TL='7'; TR=''; BL='è'; BR=''; Sub='`'; DuplicateCells=@()}
    @{Id='K8'; Label='8 (_ \)'; Type='Std'; X=524; Y=52; W=62; H=56; Col=5; Row=1; TL='8'; TR=''; BL='_'; BR=''; Sub='\'; DuplicateCells=@()}
    @{Id='K9'; Label='9 (ç ^)'; Type='Std'; X=590; Y=52; W=62; H=56; Col=6; Row=1; TL='9'; TR=''; BL='ç'; BR=''; Sub='^'; DuplicateCells=@()}
    @{Id='K0'; Label='0 (à @)'; Type='Std'; X=656; Y=52; W=62; H=56; Col=7; Row=1; TL='0'; TR=''; BL='à'; BR=''; Sub='@'; DuplicateCells=@()}
    @{Id='Degree'; Label='° ( ) ] )'; Type='Std'; X=722; Y=52; W=56; H=56; Col=7; Row=0; TL='°'; TR=''; BL=')'; BR=''; Sub=']'; DuplicateCells=@()}
    @{Id='Plus'; Label='+ (= })'; Type='Std'; X=782; Y=52; W=56; H=56; Col=5; Row=0; TL='+'; TR=''; BL='='; BR=''; Sub='}'; DuplicateCells=@()}
    @{Id='BS'; Label='Backspace'; Type='Mod'; X=842; Y=52; W=108; H=56; Col=8; Row=3; TL=''; TR='⌫'; ML=''; BL=''; DuplicateCells=@()}
    @{Id='Tab'; Label='Tab'; Type='Mod'; X=10; Y=113; W=74; H=56; Col=0; Row=3; TL='Tab'; TR='⇥'; ML=''; BL=''; DuplicateCells=@()}
    @{Id='A'; Label='A'; Type='Std'; X=88; Y=113; W=62; H=56; Col=0; Row=2; TL='A'; TR=''; BL=''; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='Z'; Label='Z'; Type='Std'; X=154; Y=113; W=62; H=56; Col=1; Row=2; TL='Z'; TR=''; BL=''; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='E'; Label='E (€)'; Type='Std'; X=220; Y=113; W=62; H=56; Col=2; Row=2; TL='E'; TR=''; BL=''; BR='€'; Sub='€'; DuplicateCells=@()}
    @{Id='R'; Label='R'; Type='Std'; X=286; Y=113; W=62; H=56; Col=3; Row=2; TL='R'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='T'; Label='T'; Type='Std'; X=352; Y=113; W=62; H=56; Col=4; Row=2; TL='T'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='Y'; Label='Y'; Type='Std'; X=418; Y=113; W=62; H=56; Col=4; Row=3; TL='Y'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='U'; Label='U'; Type='Std'; X=484; Y=113; W=62; H=56; Col=3; Row=3; TL='U'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='I'; Label='I'; Type='Std'; X=550; Y=113; W=62; H=56; Col=5; Row=2; TL='I'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='O'; Label='O'; Type='Std'; X=616; Y=113; W=62; H=56; Col=6; Row=2; TL='O'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='P'; Label='P'; Type='Std'; X=682; Y=113; W=62; H=56; Col=7; Row=2; TL='P'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='Circumflex'; Label='¨ (^)'; Type='Std'; X=748; Y=113; W=56; H=56; Col=7; Row=3; TL='¨'; TR=''; BL='^'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='Dollar'; Label='$ (£ ¤)'; Type='Std'; X=808; Y=113; W=54; H=56; Col=5; Row=3; TL='£'; TR=''; BL='$'; BR=''; Sub='¤'; DuplicateCells=@()}
    @{Id='Enter'; Label='Enter'; Type='EnterISO'; X=866; Y=113; W=84; H=117; Col=8; Row=6; TL=''; TR=''; ML=''; BL=''; Text='↵'; NotchW=16; NotchH=58; DuplicateCells=@()}
    @{Id='Caps'; Label='CapsLock'; Type='Mod'; X=10; Y=174; W=84; H=56; Col=1; Row=3; TL='⇪'; TR=''; ML=''; BL=''; Sub=''; DuplicateCells=@()}
    @{Id='Q'; Label='Q'; Type='Std'; X=98; Y=174; W=62; H=56; Col=0; Row=4; TL='Q'; TR=''; BL=''; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='S'; Label='S'; Type='Std'; X=164; Y=174; W=62; H=56; Col=1; Row=4; TL='S'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='D'; Label='D'; Type='Std'; X=230; Y=174; W=62; H=56; Col=2; Row=4; TL='D'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='F'; Label='F'; Type='Std'; X=296; Y=174; W=62; H=56; Col=3; Row=4; TL='F'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='G'; Label='G'; Type='Std'; X=362; Y=174; W=62; H=56; Col=3; Row=5; TL='G'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='H'; Label='H'; Type='Std'; X=428; Y=174; W=62; H=56; Col=4; Row=5; TL='H'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='J'; Label='J'; Type='Std'; X=494; Y=174; W=62; H=56; Col=4; Row=4; TL='J'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='K'; Label='K'; Type='Std'; X=560; Y=174; W=62; H=56; Col=5; Row=4; TL='K'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='L'; Label='L'; Type='Std'; X=626; Y=174; W=62; H=56; Col=6; Row=4; TL='L'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='M'; Label='M'; Type='Std'; X=692; Y=174; W=56; H=56; Col=7; Row=4; TL='M'; TR=''; BL=''; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='UGrave'; Label='% (ù)'; Type='Std'; X=752; Y=174; W=56; H=56; Col=7; Row=5; TL='%'; TR=''; BL='ù'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='Mu'; Label='µ (*)'; Type='Std'; X=812; Y=174; W=66; H=56; Col=7; Row=6; TL='µ'; TR=''; BL='*'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='LShift'; Label='左Shift'; Type='Mod'; X=10; Y=235; W=66; H=56; Col=14; Row=3; TL='⇧'; TR=''; ML=''; BL=''; DuplicateCells=@()}
    @{Id='IsoLess'; Label='> (<) [ISO]'; Type='Std'; X=80; Y=235; W=58; H=56; Col=1; Row=5; TL='>'; TR=''; BL='<'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='W'; Label='W'; Type='Std'; X=142; Y=235; W=62; H=56; Col=0; Row=6; TL='W'; TR=''; BL=''; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='X'; Label='X'; Type='Std'; X=208; Y=235; W=62; H=56; Col=1; Row=6; TL='X'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='C'; Label='C'; Type='Std'; X=274; Y=235; W=62; H=56; Col=2; Row=6; TL='C'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='V'; Label='V'; Type='Std'; X=340; Y=235; W=62; H=56; Col=3; Row=6; TL='V'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='B'; Label='B'; Type='Std'; X=406; Y=235; W=62; H=56; Col=3; Row=7; TL='B'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='N'; Label='N'; Type='Std'; X=472; Y=235; W=62; H=56; Col=4; Row=7; TL='N'; TR=''; BL=''; BR=''; DuplicateCells=@()}
    @{Id='Comma'; Label='? (,)'; Type='Std'; X=538; Y=235; W=62; H=56; Col=4; Row=6; TL='?'; TR=''; BL=','; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='Semicolon'; Label='. (;)'; Type='Std'; X=604; Y=235; W=62; H=56; Col=5; Row=6; TL='.'; TR=''; BL=';'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='Colon'; Label='/ (:)'; Type='Std'; X=670; Y=235; W=62; H=56; Col=6; Row=6; TL='/'; TR=''; BL=':'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='Exclam'; Label='§ (!)'; Type='Std'; X=736; Y=235; W=58; H=56; Col=7; Row=7; TL='§'; TR=''; BL='!'; BR=''; Sub=''; DuplicateCells=@()}
    @{Id='RShift'; Label='右Shift'; Type='Mod'; X=798; Y=235; W=152; H=56; Col=14; Row=6; TL=''; TR='⇧'; ML=''; BL=''; DuplicateCells=@()}
    @{Id='Fn'; Label='Fn'; Type='Mod'; X=10; Y=296; W=54; H=58; Col=1; Row=7; TL='Fn'; TR=''; ML=''; BL=''; DuplicateCells=@()}
    @{Id='LCtrl'; Label='左Ctrl'; Type='Mod'; X=68; Y=296; W=68; H=58; Col=15; Row=0; TL='Ctrl'; TR=''; ML=''; BL=''; DuplicateCells=@()}
    @{Id='LWin'; Label='Win'; Type='Mod'; X=140; Y=296; W=58; H=58; Col=9; Row=3; TL=''; TR=''; ML='⊞'; BL=''; DuplicateCells=@(@{Col=12;Row=3})}
    @{Id='LAlt'; Label='左Alt'; Type='Mod'; X=202; Y=296; W=58; H=58; Col=13; Row=5; TL='Alt'; TR=''; ML=''; BL=''; DuplicateCells=@()}
    @{Id='Space'; Label='Space'; Type='Mod'; X=264; Y=296; W=312; H=58; Col=8; Row=7; TL=''; TR=''; ML=''; BL='☀'; DuplicateCells=@()}
    @{Id='RAlt'; Label='AltGr (右Alt)'; Type='Mod'; X=580; Y=296; W=54; H=58; Col=13; Row=7; TL='AltGr'; TR=''; ML=''; BL=''; DuplicateCells=@()}
    @{Id='PrtSc'; Label='ImpÉc'; Type='Mod'; X=638; Y=296; W=54; H=58; Col=13; Row=1; TL='ImpÉc'; TR=''; ML=''; BL='✂'; Sub=''; DuplicateCells=@(@{Col=12;Row=6})}
    @{Id='RCtrl'; Label='右Ctrl'; Type='Mod'; X=696; Y=296; W=54; H=58; Col=15; Row=6; TL='Ctrl'; TR=''; ML=''; BL=''; DuplicateCells=@()}
    @{Id='PgUp'; Label='PgUp'; Type='Half'; X=754; Y=296; W=62; H=31; Col=11; Row=0; Text='PgUp'; DuplicateCells=@()}
    @{Id='Up'; Label='↑'; Type='Half'; X=821; Y=296; W=62; H=31; Col=12; Row=5; Text='↑'; DuplicateCells=@()}
    @{Id='PgDn'; Label='PgDn'; Type='Half'; X=888; Y=296; W=62; H=31; Col=11; Row=1; Text='PgDn'; DuplicateCells=@()}
    @{Id='Left'; Label='←'; Type='Half'; X=754; Y=331; W=62; H=31; Col=12; Row=7; Text='←'; DuplicateCells=@()}
    @{Id='Down'; Label='↓'; Type='Half'; X=821; Y=331; W=62; H=31; Col=10; Row=7; Text='↓'; DuplicateCells=@()}
    @{Id='Right'; Label='→'; Type='Half'; X=888; Y=331; W=62; H=31; Col=9; Row=7; Text='→'; DuplicateCells=@()}
)

# 配列管理
$Global:ActiveLayout = "JIS"

function Get-ActiveVisualKeys() {
    switch ($Global:ActiveLayout) {
        "UK" { return ($CommonFnKeys + $Layout_UK_Body + $CommonNavKeys) }
        "US" { return ($CommonFnKeys + $Layout_US_Body + $CommonNavKeys) }
        "FR" { return ($Layout_FR_FnKeys + $Layout_FR_Body + $CommonNavKeys) }
        default { return ($CommonFnKeys + $Layout_JIS_Body + $CommonNavKeys) }
    }
}
$FnLayerDefinitions = @(
    @{ Index=0;  KeyName="Fn + T";          Desc="特殊ホットキー (0x03100011)" }
    @{ Index=1;  KeyName="Fn + B";          Desc="Break (Ctrl+Pause)" }
    @{ Index=2;  KeyName="Fn + P";          Desc="Pause (0x00004800)" }
    @{ Index=3;  KeyName="Fn + S";          Desc="SysRq (Alt+PrtSc)" }
    @{ Index=4;  KeyName="Fn + PrtSc";      Desc="切り取り領域 (Win+Shift+S)" }
    @{ Index=5;  KeyName="F1 (消音)";       Desc="スピーカーミュート / F1" }
    @{ Index=6;  KeyName="F2 (音量-)";      Desc="音量ダウン / F2" }
    @{ Index=7;  KeyName="F3 (音量+)";      Desc="音量アップ / F3" }
    @{ Index=8;  KeyName="F4 (マイク消音)"; Desc="マイクミュート / F4" }
    @{ Index=9;  KeyName="F5 (輝度-)";      Desc="画面輝度ダウン / F5" }
    @{ Index=10; KeyName="F6 (輝度+)";      Desc="画面輝度アップ / F6" }
    @{ Index=11; KeyName="F7 (画面投影)";   Desc="ディスプレイ投影 (Win+P) / F7" }
    @{ Index=12; KeyName="F8 (機内モード)"; Desc="機内モード切替 / F8" }
    @{ Index=13; KeyName="F9 (通知)";       Desc="通知センター (Win+A) / F9" }
    @{ Index=14; KeyName="F10 (受話)";      Desc="Teams通話応答 / F10" }
    @{ Index=15; KeyName="F11 (終話)";      Desc="Teams通話終了 / F11" }
    @{ Index=16; KeyName="F12 (☆ユーザー)"; Desc="Vantage / ユーザー定義キー / F12" }
    @{ Index=17; KeyName="Fn + Space";      Desc="キーボードバックライト切替" }
    @{ Index=18; KeyName="Fn + K";          Desc="ScrollLock (0x00004700)" }
    @{ Index=19; KeyName="Fn + 4";          Desc="システムスリープ (0x01008200)" }
    @{ Index=20; KeyName="Fn + Esc";        Desc="FnLock 切替" }
    @{ Index=21; KeyName="Fn + End";        Desc="Insert (0x00004900)" }
    @{ Index=22; KeyName="Fn + ←";          Desc="Home (0x00004A00)" }
    @{ Index=23; KeyName="Fn + →";          Desc="End (0x00004D00)" }
    @{ Index=24; KeyName="Fn + Tab";        Desc="拡大鏡 / 特殊機能" }
    @{ Index=26; KeyName="Fn + D";          Desc="特殊ホットキー (0x03100022)" }
)

# Fnレイヤーで選択可能なプリセット動作値
$FnActionPresets = @(
    [PSCustomObject]@{ Value = [uint32]0x00000000;   Label = "【無効化 (0x00000000)】" }
    [PSCustomObject]@{ Value = [uint32]0x03E20000;   Label = "ミュート (Mute: 0x03E20000)" }
    [PSCustomObject]@{ Value = [uint32]0x03EA0000;   Label = "音量ダウン (Vol-: 0x03EA0000)" }
    [PSCustomObject]@{ Value = [uint32]0x03E90000;   Label = "音量アップ (Vol+: 0x03E90000)" }
    [PSCustomObject]@{ Value = [uint32]0x03000200;   Label = "マイクミュート (0x03000200)" }
    [PSCustomObject]@{ Value = [uint32]0x03700000;   Label = "画面輝度ダウン (0x03700000)" }
    [PSCustomObject]@{ Value = [uint32]0x036F0000;   Label = "画面輝度アップ (0x036F0000)" }
    [PSCustomObject]@{ Value = [uint32]"0xFFFFFF3E"; Label = "画面投影 Win+P (0xFFFFFF3E)" }
    [PSCustomObject]@{ Value = [uint32]0x03004000;   Label = "機内モード (0x03004000)" }
    [PSCustomObject]@{ Value = [uint32]"0xFFFFFF3B"; Label = "通知センター Win+A (0xFFFFFF3B)" }
    [PSCustomObject]@{ Value = [uint32]0x03080000;   Label = "切り取り領域 Snipping (0x03080000)" }
    [PSCustomObject]@{ Value = [uint32]"0xFFFFFF0D"; Label = "バックライト切替 (0xFFFFFF0D)" }
    [PSCustomObject]@{ Value = [uint32]"0xFFFFFF0C"; Label = "FnLock 切替 (0xFFFFFF0C)" }
    [PSCustomObject]@{ Value = [uint32]0x01008200;   Label = "スリープ Sleep (0x01008200)" }
    [PSCustomObject]@{ Value = [uint32]0x00004900;   Label = "Insert キー (0x00004900)" }
    [PSCustomObject]@{ Value = [uint32]0x00004A00;   Label = "Home キー (0x00004A00)" }
    [PSCustomObject]@{ Value = [uint32]0x00004D00;   Label = "End キー (0x00004D00)" }
    [PSCustomObject]@{ Value = [uint32]0x00004B00;   Label = "PageUp キー (0x00004B00)" }
    [PSCustomObject]@{ Value = [uint32]0x00004E00;   Label = "PageDown キー (0x00004E00)" }
    [PSCustomObject]@{ Value = [uint32]0x00004800;   Label = "Pause キー (0x00004800)" }
    [PSCustomObject]@{ Value = [uint32]0x00004700;   Label = "ScrollLock キー (0x00004700)" }
    [PSCustomObject]@{ Value = [uint32]"0xFFFFFF3F"; Label = "Break (Ctrl+Pause: 0xFFFFFF3F)" }
    [PSCustomObject]@{ Value = [uint32]"0xFFFFFFA9"; Label = "SysRq (Alt+PrtSc: 0xFFFFFFA9)" }
    [PSCustomObject]@{ Value = [uint32]0x00003A00;   Label = "標準 F1 (0x00003A00)" }
    [PSCustomObject]@{ Value = [uint32]0x00003B00;   Label = "標準 F2 (0x00003B00)" }
    [PSCustomObject]@{ Value = [uint32]0x00003C00;   Label = "標準 F3 (0x00003C00)" }
    [PSCustomObject]@{ Value = [uint32]0x00003D00;   Label = "標準 F4 (0x00003D00)" }
    [PSCustomObject]@{ Value = [uint32]0x00003E00;   Label = "標準 F5 (0x00003E00)" }
    [PSCustomObject]@{ Value = [uint32]0x00003F00;   Label = "標準 F6 (0x00003F00)" }
    [PSCustomObject]@{ Value = [uint32]0x00004000;   Label = "標準 F7 (0x00004000)" }
    [PSCustomObject]@{ Value = [uint32]0x00004100;   Label = "標準 F8 (0x00004100)" }
    [PSCustomObject]@{ Value = [uint32]0x00004200;   Label = "標準 F9 (0x00004200)" }
    [PSCustomObject]@{ Value = [uint32]0x00004300;   Label = "標準 F10 (0x00004300)" }
    [PSCustomObject]@{ Value = [uint32]0x00004400;   Label = "標準 F11 (0x00004400)" }
    [PSCustomObject]@{ Value = [uint32]0x00004500;   Label = "標準 F12 (0x00004500)" }
)

function Format-FnActionValue([uint32]$val) {
    foreach ($p in $FnActionPresets) {
        if ($p.Value -eq $val) { return $p.Label }
    }
    return ("0x{0:X8}" -f $val)
}

# 初回バックアップの作成
if ((Test-Path $BinPath) -and -not (Test-Path $BinBak)) {
    Copy-Item -Path $BinPath -Destination $BinBak -Force
}
if ((Test-Path $IspPath) -and -not (Test-Path $IspBak)) {
    Copy-Item -Path $IspPath -Destination $IspBak -Force
}

if (-not (Test-Path $BinPath)) {
    [System.Windows.MessageBox]::Show("ファームウェアファイルが見つかりません:`n$BinPath", "エラー", "OK", "Error") | Out-Null
    exit 1
}

[byte[]]$Global:CurrentBinBytes = [System.IO.File]::ReadAllBytes($BinPath)
[byte[]]$Global:OrigBinBytes    = if (Test-Path $BinBak) { [System.IO.File]::ReadAllBytes($BinBak) } else { [byte[]]$Global:CurrentBinBytes.Clone() }

function Read-UInt32LE([byte[]]$buf, [int]$offset) {
    return [System.BitConverter]::ToUInt32($buf, $offset)
}

function Write-UInt32LE([byte[]]$buf, [int]$offset, [uint32]$value) {
    $bytes = [System.BitConverter]::GetBytes($value)
    [System.Array]::Copy($bytes, 0, $buf, $offset, 4)
}

function Get-MatrixOffset([int]$col, [int]$row) {
    return $MATRIX_OFFSET + (($col * 8 + $row) * 4)
}

# WPF XAML 定義 (Windows 11 Fluent Design ライトテーマ / BIZ UDPGothic)
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ThinkPad X12 Detachable Gen 1 キーボード用ファームウェア キー入れ替え・無効化ツール"
        Width="1260" Height="880" MinWidth="1080" MinHeight="760"
        WindowStartupLocation="CenterScreen"
        Background="#F4F5F7" FontFamily="BIZ UDPGothic" TextOptions.TextFormattingMode="Display">
    <Window.Resources>
        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#E2E8F0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="14"/>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="#0284C7"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#0284C7"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#0369A1"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#0369A1"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Background" Value="#CBD5E1"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#CBD5E1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#1E293B"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#F1F5F9"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#0284C7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button">
            <Setter Property="Background" Value="#FEF2F2"/>
            <Setter Property="Foreground" Value="#DC2626"/>
            <Setter Property="BorderBrush" Value="#FECACA"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="11,6"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#FEE2E2"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#EF4444"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- モダンピル型ラジオボタンスタイル -->
        <Style x:Key="LayoutRadio" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#475569"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="RadioBorder" Background="Transparent" CornerRadius="6" Padding="7,3" BorderThickness="1" BorderBrush="Transparent">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="RadioBorder" Property="Background" Value="#0284C7"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="RadioBorder" Property="BorderBrush" Value="#38BDF8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="95"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- ヘッダーカード (2段構成: タイトル行 ＆ 配列切替・対象情報行) -->
        <Border Grid.Row="0" Style="{StaticResource CardBorder}" Margin="0,0,0,10" Padding="16,10">
            <StackPanel>
                <!-- 1段目: タイトル ＆ JSON保存・読込ボタン -->
                <DockPanel>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Background="#0284C7" CornerRadius="4" Padding="8,2" Margin="0,0,10,0">
                            <TextBlock Text="ThinkPad X12 Detachable Gen 1" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF"/>
                        </Border>
                        <TextBlock Text="キーボード用ファームウェア キー入れ替え・無効化ツール" FontSize="16" FontWeight="Bold" Foreground="#1E293B"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <Button x:Name="BtnExportJson" Content="設定をJSON保存" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                        <Button x:Name="BtnImportJson" Content="設定をJSON読込" Style="{StaticResource SecondaryButton}"/>
                    </StackPanel>
                </DockPanel>

                <Separator Margin="0,8,0,8" Background="#F1F5F9"/>

                <!-- 2段目: 対象ファイル情報 ＆ キーボード配列切替ピル（ゆったり独立配置） -->
                <DockPanel>
                    <TextBlock x:Name="TxtSubHeader" Text="対象: Hera_KB_APROM_v39_UT0N.bin (マトリクス / Fnレイヤー) ＆ KB-ISP.exe パッチ" FontSize="11.5" Foreground="#64748B" VerticalAlignment="Center"/>

                    <!-- 右側: 配列切り替えピル型ボタングループ (広々とした右揃え) -->
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="キーボード配列:" FontSize="12.5" FontWeight="Bold" Foreground="#1E293B" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <ComboBox x:Name="CmbLayout" Width="240" Height="34" FontSize="12.5" FontWeight="SemiBold" VerticalContentAlignment="Center" Background="#FFFFFF" BorderBrush="#CBD5E1">
                            <ComboBoxItem Content="🇯🇵 日本語 (JIS 88キー)" Tag="JIS" IsSelected="True"/>
                            <ComboBoxItem Content="🇬🇧 英語 (UK 84キー)" Tag="UK"/>
                            <ComboBoxItem Content="🇺🇸 英語 (US 83キー)" Tag="US"/>
                            <ComboBoxItem Content="🇫🇷 フランス語 (FR 84キー)" Tag="FR"/>
                        </ComboBox>
                    </StackPanel>
                </DockPanel>
            </StackPanel>
        </Border>

        <!-- メインタブ -->
        <TabControl x:Name="TabMain" Grid.Row="1" Background="Transparent" BorderThickness="0" Padding="0">
            <!-- タブ1: ビジュアル・キーボード編集 -->
            <TabItem Header="  1. 通常キー入れ替え・無効化 (実機ビジュアル配列・4配列切替対応)  " FontSize="13" FontWeight="Bold">
                <Grid Margin="0,8,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="315"/>
                    </Grid.ColumnDefinitions>

                    <!-- 左側: 実機忠実再現ビジュアルキーボードマップ -->
                    <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <DockPanel Grid.Row="0" Margin="0,0,0,6">
                                <TextBlock x:Name="TxtKeyboardTitle" Text="日本語 (JIS 88キー) 配列（クリックして選択/入替）" FontSize="14" FontWeight="Bold" Foreground="#1E293B" VerticalAlignment="Center"/>
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                    <Border Background="#23262C" BorderBrush="#475569" BorderThickness="1" CornerRadius="3" Width="14" Height="14" Margin="8,0,4,0"/>
                                    <TextBlock Text="純正標準" FontSize="11" Foreground="#64748B" VerticalAlignment="Center"/>
                                    <Border Background="#0C4A6E" BorderBrush="#38BDF8" BorderThickness="1.5" CornerRadius="3" Width="14" Height="14" Margin="10,0,4,0"/>
                                    <TextBlock Text="変更済" FontSize="11" Foreground="#0284C7" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <Border Background="#7F1D1D" BorderBrush="#F87171" BorderThickness="1.5" CornerRadius="3" Width="14" Height="14" Margin="10,0,4,0"/>
                                    <TextBlock Text="無効化" FontSize="11" Foreground="#DC2626" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <Border Background="#23262C" BorderBrush="#F59E0B" BorderThickness="2" CornerRadius="3" Width="14" Height="14" Margin="10,0,4,0"/>
                                    <TextBlock Text="選択中/入替待機" FontSize="11" Foreground="#D97706" FontWeight="Bold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </DockPanel>

                            <!-- 実機ベゼル＆2D Canvas -->
                            <Viewbox Grid.Row="1" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center">
                                <Border Background="#181A1F" BorderBrush="#2D3139" BorderThickness="3" CornerRadius="12" Padding="8,8,8,6">
                                    <Canvas x:Name="KeyboardCanvas" Width="960" Height="404" Background="#14161A"/>
                                </Border>
                            </Viewbox>

                            <!-- 配列連動ワンクリックプリセット -->
                            <Border Grid.Row="2" Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="6" Padding="10,6" Margin="0,6,0,0">
                                <WrapPanel x:Name="PresetWrapPanel" VerticalAlignment="Center">
                                    <!-- 動的に生成されます -->
                                </WrapPanel>
                            </Border>
                        </Grid>
                    </Border>

                    <!-- 右側: 選択キー編集パネル -->
                    <Border Grid.Column="1" Style="{StaticResource CardBorder}" Padding="12">
                        <StackPanel>
                            <TextBlock Text="選択中のキー設定" FontSize="14.5" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,6"/>

                            <Border Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="6" Padding="8" Margin="0,0,0,8">
                                <StackPanel>
                                    <TextBlock Text="物理キー位置:" FontSize="11" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtSelKeyTitle" Text="（左のキーボードから選択）" FontSize="15" FontWeight="Bold" Foreground="#0284C7" Margin="0,1,0,5"/>

                                    <TextBlock Text="マトリクス座標 / ROMオフセット:" FontSize="11" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtSelCoord" Text="-" FontFamily="Consolas" FontSize="11.5" Foreground="#1E293B" Margin="0,1,0,5"/>

                                    <TextBlock Text="純正の初期割り当て:" FontSize="11" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtSelOrigCode" Text="-" FontSize="11.5" Foreground="#1E293B" TextWrapping="Wrap" Margin="0,1,0,5"/>

                                    <TextBlock Text="現在の割り当て:" FontSize="11" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtSelCurrCode" Text="-" FontSize="12" FontWeight="Bold" Foreground="#1E293B" TextWrapping="Wrap" Margin="0,1,0,0"/>
                                </StackPanel>
                            </Border>

                            <TextBlock Text="1. リストから別のキーに変更:" FontSize="12" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,3"/>
                            <ComboBox x:Name="CmbTargetKey" Height="30" FontSize="12" Margin="0,0,0,6"/>
                            <Button x:Name="BtnApplyKey" Content="選択したキーを割り当てる" Style="{StaticResource PrimaryButton}" Padding="12,6" Margin="0,0,0,10"/>

                            <TextBlock Text="2. キーの入れ替え (Swap) / 無効化:" FontSize="12" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,4"/>
                            <Button x:Name="BtnStartSwap" Content="他のキーと入れ替える (Swapモード)" Style="{StaticResource SecondaryButton}" Padding="10,5" FontSize="12" Margin="0,0,0,6"/>
                            <Button x:Name="BtnDisableKey" Content="このキーを無効化する (0x00000000)" Style="{StaticResource DangerButton}" Padding="10,5" Margin="0,0,0,6"/>
                            <Button x:Name="BtnRestoreKey" Content="このキーを純正初期値に戻す" Style="{StaticResource SecondaryButton}" Padding="10,5" FontSize="12" Margin="0,0,0,10"/>

                            <TextBlock Text="3. 16進コード直接入力 (上級者向け):" FontSize="11" Foreground="#64748B" Margin="0,0,0,3"/>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="TxtCustomHex" Grid.Column="0" Height="28" FontFamily="Consolas" FontSize="13" VerticalContentAlignment="Center" Padding="6,0" Margin="0,0,6,0" Text="0x00000000"/>
                                <Button x:Name="BtnApplyHex" Grid.Column="1" Content="HEX適用" Style="{StaticResource SecondaryButton}" Padding="10,5"/>
                            </Grid>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- タブ2: Fn組み合わせ・メディアキー編集 -->
            <TabItem Header="  2. Fn組み合わせ・メディアキー編集 (Fn+4 スリープ等)  " FontSize="13" FontWeight="Bold">
                <Grid Margin="0,8,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="340"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="Fnレイヤー・特殊ホットキーテーブル (ROMオフセット 0x5B50 [FnLock時] / 0x5BD0 [通常メディア時])" FontSize="13" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,8"/>
                            <DataGrid x:Name="GridFnLayer" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True"
                                      SelectionMode="Single" CanUserAddRows="False" RowHeaderWidth="0"
                                      Background="#FFFFFF" BorderBrush="#E2E8F0" GridLinesVisibility="Horizontal"
                                      HorizontalGridLinesBrush="#F1F5F9" FontSize="12" RowHeight="28">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="No" Binding="{Binding Index}" Width="40"/>
                                    <DataGridTextColumn Header="キー組み合わせ" Binding="{Binding KeyName}" Width="130" FontWeight="Bold"/>
                                    <DataGridTextColumn Header="機能説明" Binding="{Binding Desc}" Width="210"/>
                                    <DataGridTextColumn Header="通常メディア枠 (0x5BD0)" Binding="{Binding MediaHex}" Width="175" FontFamily="Consolas"/>
                                    <DataGridTextColumn Header="FnLock枠 (0x5B50)" Binding="{Binding FnLockHex}" Width="175" FontFamily="Consolas"/>
                                    <DataGridTextColumn Header="状態" Binding="{Binding Status}" Width="80"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </Grid>
                    </Border>

                    <Border Grid.Column="1" Style="{StaticResource CardBorder}">
                        <StackPanel>
                            <TextBlock Text="選択中のFnホットキー編集" FontSize="15" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,10"/>
                            <Border Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,12">
                                <StackPanel>
                                    <TextBlock Text="対象ホットキー:" FontSize="11" Foreground="#64748B"/>
                                    <TextBlock x:Name="TxtFnSelTitle" Text="（左の表から行を選択）" FontSize="15" FontWeight="Bold" Foreground="#0284C7" Margin="0,2,0,6"/>
                                    <TextBlock x:Name="TxtFnSelDesc" Text="-" FontSize="12" Foreground="#64748B" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Border>

                            <TextBlock Text="プリセット動作を選択して適用:" FontSize="12" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbFnPreset" Height="32" FontSize="12" Margin="0,0,0,8"/>
                            <Button x:Name="BtnFnApplyBoth" Content="通常枠・FnLock枠の両方に適用" Style="{StaticResource PrimaryButton}" Margin="0,0,0,6"/>
                            <Button x:Name="BtnFnApplyMedia" Content="通常メディア枠 (0x5BD0) のみに適用" Style="{StaticResource SecondaryButton}" Padding="11,6" FontSize="12" Margin="0,0,0,6"/>
                            <Button x:Name="BtnFnApplyFnLock" Content="FnLock枠 (0x5B50) のみに適用" Style="{StaticResource SecondaryButton}" Padding="11,6" FontSize="12" Margin="0,0,0,14"/>

                            <TextBlock Text="ワンクリック操作:" FontSize="12" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,6"/>
                            <Button x:Name="BtnFnDisable" Content="このFn組み合わせを完全に無効化 (0x00000000)" Style="{StaticResource DangerButton}" Margin="0,0,0,8"/>
                            <Button x:Name="BtnFnRestore" Content="このFn組み合わせを純正初期値に戻す" Style="{StaticResource SecondaryButton}" Padding="11,6" FontSize="12" Margin="0,0,0,8"/>
                            <Button x:Name="BtnFnF1F12Standard" Content="F1〜F12を常に標準F1〜F12として動作させる" Style="{StaticResource SecondaryButton}" Padding="11,6" FontSize="12"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- タブ3: KB-ISP.exe 制限解除パッチ設定 ＆ 変更一覧 -->
            <TabItem Header="  3. KB-ISP.exe 制限解除オプション ＆ 変更箇所サマリー  " FontSize="13" FontWeight="Bold">
                <Grid Margin="0,8,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="460"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,0">
                        <StackPanel>
                            <TextBlock Text="KB-ISP.exe (書き込みツール) 動作パッチ設定" FontSize="15" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,12"/>

                            <CheckBox x:Name="ChkSyncIspBin" IsChecked="True" IsEnabled="False" FontSize="13" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,6">
                                <TextBlock Text="KB-ISP.exe 内部の埋め込みファームウェア (0x23B630) を同期更新する 【必須】" TextWrapping="Wrap"/>
                            </CheckBox>
                            <TextBlock Text="※KB-ISP.exeは起動時に毎回自身の内部リソース(0x23B630)から FW\Hera_KB_APROM_v39_UT0N.bin を上書き展開するため、両方を同時に書き換えます。" FontSize="11" Foreground="#64748B" TextWrapping="Wrap" Margin="22,0,0,14"/>

                            <CheckBox x:Name="ChkDisableReboot" IsChecked="True" FontSize="13" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,6">
                                <TextBlock Text="ファームウェア更新完了後のPC強制再起動 (shutdown -f -r -t 0) を無効化する 【推奨】" TextWrapping="Wrap"/>
                            </CheckBox>
                            <TextBlock Text="※KB-ISP.exe 内のオフセット 0x0187AC (13バイト) の system(&quot;shutdown -f -r -t 0&quot;) 呼び出しをNOP化します。書き込み完了後、PCを再起動せずにすぐキーボードを使用できます。" FontSize="11" Foreground="#64748B" TextWrapping="Wrap" Margin="22,0,0,14"/>

                            <CheckBox x:Name="ChkSkipPowerCheck" IsChecked="True" FontSize="13" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,6">
                                <TextBlock Text="AC電源接続・バッテリー残量 (25%以上) チェックをスキップする 【推奨】" TextWrapping="Wrap"/>
                            </CheckBox>
                            <TextBlock Text="※KB-ISP.exe 内のオフセット 0x01CCD0 (20バイト) の電源判定分岐をNOP化します。デスクトップPC（バッテリー非搭載機）やバッテリー駆動時のノートPCでもエラーを出さずに書き込めます。" FontSize="11" Foreground="#64748B" TextWrapping="Wrap" Margin="22,0,0,14"/>

                            <CheckBox x:Name="ChkSkipVersionCheck" IsChecked="True" FontSize="13" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,6">
                                <TextBlock Text="ファームウェア バージョンチェック (同一/過去バージョンの上書き禁止) を無効化する 【推奨・再書き込み必須】" TextWrapping="Wrap"/>
                            </CheckBox>
                            <TextBlock Text="※KB-ISP.exe 内のオフセット 0x01CCB6 (2バイト: 74 18 -> EB 18) のバージョン判定分岐を短絡化します。一度書き換えた後に2回目以降のキーマップ修正を行う際、『A newer version is currently installed.』エラーで書き込みが拒否される問題を解消します。" FontSize="11" Foreground="#64748B" TextWrapping="Wrap" Margin="22,0,0,14"/>

                            <Border Background="#F0F9FF" BorderBrush="#BAE6FD" BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,8,0,0">
                                <StackPanel>
                                    <TextBlock Text="バックアップ状態" FontSize="13" FontWeight="Bold" Foreground="#0369A1" Margin="0,0,0,4"/>
                                    <TextBlock x:Name="TxtBackupStatus" Text="-" FontSize="12" Foreground="#1E293B" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Border>

                    <Border Grid.Column="1" Style="{StaticResource CardBorder}">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="純正ファームウェアからの変更箇所一覧 (Diffプレビュー)" FontSize="14" FontWeight="Bold" Foreground="#1E293B" Margin="0,0,0,8"/>
                            <TextBox x:Name="TxtDiffPreview" Grid.Row="1" FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                                     Background="#F8FAFC" Foreground="#1E293B" BorderBrush="#CBD5E1" Padding="10"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>
        </TabControl>

        <!-- ログ出力領域 -->
        <Border Grid.Row="2" Style="{StaticResource CardBorder}" Margin="0,8,0,8" Padding="10,8">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="操作ログ・バイナリ検証ステータス" FontSize="12" FontWeight="Bold" Foreground="#64748B" Margin="0,0,0,4"/>
                <TextBox x:Name="TxtLog" Grid.Row="1" FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                         VerticalScrollBarVisibility="Auto" Background="#F8FAFC" Foreground="#1E293B" BorderBrush="#E2E8F0" Padding="6"/>
            </Grid>
        </Border>

        <!-- フッターアクションバー (2段構成: ステータス表示行 ＆ 操作ボタン行) -->
        <Border Grid.Row="3" Style="{StaticResource CardBorder}" Padding="16,10">
            <StackPanel>
                <!-- 上段: 変更数 ＆ チェックサム情報 (文字被りを完全に防止する専用独立行) -->
                <Border Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="6" Padding="12,6" Margin="0,0,0,10">
                    <DockPanel>
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="📊 " FontSize="12.5" VerticalAlignment="Center"/>
                            <TextBlock x:Name="TxtFooterSummary" Text="純正からの変更数: 0 箇所  |  現在のROMチェックサム(16bit): 0x0000" FontSize="12.5" FontWeight="Bold" Foreground="#0284C7" VerticalAlignment="Center"/>
                        </StackPanel>
                        <TextBlock Text="※変更内容は『ファームウェア ＆ KB-ISP.exe に保存 (パッチ適用)』を押すまでファイルには書き込まれません" FontSize="11" Foreground="#64748B" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                    </DockPanel>
                </Border>

                <!-- 下段: 操作ボタン行 -->
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- 左側: リセットボタン -->
                    <Button x:Name="BtnRestoreAllOrig" Grid.Column="0" Content="↺ すべて純正初期状態に復元 (バックアップから戻す)" Style="{StaticResource DangerButton}" Height="34" Padding="12,0"/>

                    <!-- 右側: 保存ボタン -->
                    <StackPanel Grid.Column="2" Orientation="Horizontal">
                        <Button x:Name="BtnSavePatch" Content="💾 ファームウェア ＆ KB-ISP.exe に保存 (パッチ適用)" Style="{StaticResource PrimaryButton}" Height="34" Padding="16,0"/>
                    </StackPanel>
                </Grid>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [System.Windows.Markup.XamlReader]::Load($Reader)

# コントロール参照取得
$CmbLayout           = $Window.FindName("CmbLayout")
$TxtKeyboardTitle    = $Window.FindName("TxtKeyboardTitle")
$KeyboardCanvas      = $Window.FindName("KeyboardCanvas")
$PresetWrapPanel     = $Window.FindName("PresetWrapPanel")
$TxtSelKeyTitle          = $Window.FindName("TxtSelKeyTitle")
$TxtSelCoord             = $Window.FindName("TxtSelCoord")
$TxtSelOrigCode          = $Window.FindName("TxtSelOrigCode")
$TxtSelCurrCode          = $Window.FindName("TxtSelCurrCode")
$CmbTargetKey            = $Window.FindName("CmbTargetKey")
$BtnApplyKey             = $Window.FindName("BtnApplyKey")
$BtnStartSwap            = $Window.FindName("BtnStartSwap")
$BtnDisableKey           = $Window.FindName("BtnDisableKey")
$BtnRestoreKey           = $Window.FindName("BtnRestoreKey")
$TxtCustomHex            = $Window.FindName("TxtCustomHex")
$BtnApplyHex             = $Window.FindName("BtnApplyHex")

# (Preset buttons are now dynamically generated in PresetWrapPanel)

$GridFnLayer             = $Window.FindName("GridFnLayer")
$TxtFnSelTitle           = $Window.FindName("TxtFnSelTitle")
$TxtFnSelDesc            = $Window.FindName("TxtFnSelDesc")
$CmbFnPreset             = $Window.FindName("CmbFnPreset")
$BtnFnApplyBoth          = $Window.FindName("BtnFnApplyBoth")
$BtnFnApplyMedia         = $Window.FindName("BtnFnApplyMedia")
$BtnFnApplyFnLock        = $Window.FindName("BtnFnApplyFnLock")
$BtnFnDisable            = $Window.FindName("BtnFnDisable")
$BtnFnRestore            = $Window.FindName("BtnFnRestore")
$BtnFnF1F12Standard      = $Window.FindName("BtnFnF1F12Standard")

$ChkDisableReboot        = $Window.FindName("ChkDisableReboot")
$ChkSkipPowerCheck       = $Window.FindName("ChkSkipPowerCheck")
$ChkSkipVersionCheck     = $Window.FindName("ChkSkipVersionCheck")
$TxtBackupStatus         = $Window.FindName("TxtBackupStatus")
$TxtDiffPreview          = $Window.FindName("TxtDiffPreview")
$TxtLog                  = $Window.FindName("TxtLog")
$TxtFooterSummary        = $Window.FindName("TxtFooterSummary")

$BtnExportJson           = $Window.FindName("BtnExportJson")
$BtnImportJson           = $Window.FindName("BtnImportJson")
$BtnRestoreAllOrig       = $Window.FindName("BtnRestoreAllOrig")
$BtnSavePatch            = $Window.FindName("BtnSavePatch")

function Get-EnterPathData([double]$W, [double]$H, [double]$nw, [double]$nh) {
    $rt = 4.0
    $rb = 7.0
    $ro = 3.5
    $ri = 3.5

    $x_tl_start = $rt
    $x_tr_end   = $W - $rt
    $x_right    = $W - 1.0
    $y_tr_start = $rt + 1.0
    $y_br_end   = $H - $rb - 1.0
    $y_bottom   = $H - 1.0
    $x_br_start = $W - $rb - 1.0
    $x_bl_end   = $nw + $rb + 1.0
    $x_notch    = $nw + 1.0
    $y_bl_start = $H - $rb - 1.0
    $y_notch_in = $nh + $ri + 1.0
    $y_notch_h  = $nh + 1.0
    $x_notch_in = $nw - $ri
    $x_notch_out= $ro + 1.0
    $y_notch_out= $nh - $ro
    $y_tl_end   = $rt + 1.0

    $p = "M {0:F1},1.0 " -f $x_tl_start
    $p += "L {0:F1},1.0 " -f $x_tr_end
    $p += "A {0:F1},{0:F1} 0 0 1 {1:F1},{2:F1} " -f $rt, $x_right, $y_tr_start
    $p += "L {0:F1},{1:F1} " -f $x_right, $y_br_end
    $p += "A {0:F1},{0:F1} 0 0 1 {1:F1},{2:F1} " -f $rb, $x_br_start, $y_bottom
    $p += "L {0:F1},{1:F1} " -f $x_bl_end, $y_bottom
    $p += "A {0:F1},{0:F1} 0 0 1 {1:F1},{2:F1} " -f $rb, $x_notch, $y_bl_start
    $p += "L {0:F1},{1:F1} " -f $x_notch, $y_notch_in
    $p += "A {0:F1},{0:F1} 0 0 0 {1:F1},{2:F1} " -f $ri, $x_notch_in, $y_notch_h
    $p += "L {0:F1},{1:F1} " -f $x_notch_out, $y_notch_h
    $p += "A {0:F1},{0:F1} 0 0 1 1.0,{1:F1} " -f $ro, $y_notch_out
    $p += "L 1.0,{0:F1} " -f $y_tl_end
    $p += "A {0:F1},{0:F1} 0 0 1 {1:F1},1.0 " -f $rt, $x_tl_start
    $p += "Z"
    return $p
}

$BrushConv = New-Object System.Windows.Media.BrushConverter
function Get-Brush([string]$hex) { return $BrushConv.ConvertFromString($hex) }

function Write-Log([string]$msg) {
    $ts = (Get-Date).ToString("HH:mm:ss")
    $TxtLog.AppendText("[$ts] $msg`r`n")
    $TxtLog.ScrollToEnd()
}

# コンボボックス初期化
foreach ($item in $HidKeyCatalog) {
    $CmbTargetKey.Items.Add(("{0} - {1} [0x{2:X8}]" -f $item.Category, $item.Name, $item.Code)) | Out-Null
}
$CmbTargetKey.SelectedIndex = 0

foreach ($p in $FnActionPresets) {
    $CmbFnPreset.Items.Add($p.Label) | Out-Null
}
$CmbFnPreset.SelectedIndex = 0

# 状態管理変数
$Global:KeyButtons    = @{}
$Global:SelectedKey   = $null
$Global:SwapSourceKey = $null

# キャンバス再構築関数 (配列切り替え時などに呼出)
function Rebuild-KeyboardCanvas() {
    $KeyboardCanvas.Children.Clear()
    $Global:KeyButtons.Clear()

    $activeKeys = Get-ActiveVisualKeys

    # 1. キーボタン配置
    foreach ($k in $activeKeys) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Width  = $k.W
        $btn.Height = $k.H
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Tag    = $k
        $btn.BorderThickness = New-Object System.Windows.Thickness(0)
        $btn.Background      = [System.Windows.Media.Brushes]::Transparent
        $btn.Padding         = New-Object System.Windows.Thickness(0)

        $tmpl = New-Object System.Windows.Controls.ControlTemplate([System.Windows.Controls.Button])
        $pres = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
        $tmpl.VisualTree = $pres
        $btn.Template = $tmpl

        [System.Windows.Controls.Canvas]::SetLeft($btn, $k.X)
        [System.Windows.Controls.Canvas]::SetTop($btn,  $k.Y)
        [System.Windows.Controls.Panel]::SetZIndex($btn, 10)

        $Global:KeyButtons[$k.Id] = $btn
        $btn.Add_Click({
            param($sender, $e)
            On-KeyButtonClicked $sender.Tag
        })
        $KeyboardCanvas.Children.Add($btn) | Out-Null
    }

    # 2. 実機の赤い TrackPoint キャップ (G・H・B の中央: X=426, Y=221)
    $tpOuter = New-Object System.Windows.Shapes.Ellipse
    $tpOuter.Width  = 24; $tpOuter.Height = 24
    $tpOuter.Fill   = Get-Brush "#DC2626"; $tpOuter.Stroke = Get-Brush "#7F1D1D"; $tpOuter.StrokeThickness = 2
    $tpOuter.IsHitTestVisible = $false
    [System.Windows.Controls.Canvas]::SetLeft($tpOuter, 426)
    [System.Windows.Controls.Canvas]::SetTop($tpOuter,  221)
    [System.Windows.Controls.Panel]::SetZIndex($tpOuter, 50)
    $KeyboardCanvas.Children.Add($tpOuter) | Out-Null

    $tpInner = New-Object System.Windows.Shapes.Ellipse
    $tpInner.Width  = 16; $tpInner.Height = 16
    $tpInner.Fill   = Get-Brush "#EF4444"; $tpInner.Stroke = Get-Brush "#B91C1C"; $tpInner.StrokeThickness = 1
    $tpInner.IsHitTestVisible = $false
    [System.Windows.Controls.Canvas]::SetLeft($tpInner, 430)
    [System.Windows.Controls.Canvas]::SetTop($tpInner,  225)
    [System.Windows.Controls.Panel]::SetZIndex($tpInner, 51)
    $KeyboardCanvas.Children.Add($tpInner) | Out-Null

    # 3. 実機下部トラックポイント物理3ボタンバー装飾 (Spaceキーの幅・位置に連動)
    $spaceKey = $activeKeys | Where-Object { $_.Id -eq "Space" } | Select-Object -First 1
    $tpBarX = if ($spaceKey) { $spaceKey.X } else { 264 }
    $tpBarW = if ($spaceKey) { $spaceKey.W } else { 312 }

    $tpBar = New-Object System.Windows.Controls.Border
    $tpBar.Width  = $tpBarW
    $tpBar.Height = 30
    $tpBar.Background = Get-Brush "#1E2026"
    $tpBar.BorderBrush = Get-Brush "#2E323B"
    $tpBar.BorderThickness = New-Object System.Windows.Thickness(1)
    $tpBar.CornerRadius = New-Object System.Windows.CornerRadius(3)
    [System.Windows.Controls.Canvas]::SetLeft($tpBar, $tpBarX)
    [System.Windows.Controls.Canvas]::SetTop($tpBar,  366)

    $tpGrid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength([Math]::Min(76, [int]($tpBarW * 0.3)))
    $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $tpGrid.ColumnDefinitions.Add($c1); $tpGrid.ColumnDefinitions.Add($c2); $tpGrid.ColumnDefinitions.Add($c3)

    $redLineL = New-Object System.Windows.Controls.Border
    $redLineL.Height = 2.5; $redLineL.Background = Get-Brush "#DC2626"; $redLineL.VerticalAlignment = "Bottom"; $redLineL.Margin = New-Object System.Windows.Thickness(2,0,2,2)
    [System.Windows.Controls.Grid]::SetColumn($redLineL, 0)

    $redLineM = New-Object System.Windows.Controls.Border
    $redLineM.Height = 2.5; $redLineM.Background = Get-Brush "#DC2626"; $redLineM.VerticalAlignment = "Top"; $redLineM.Margin = New-Object System.Windows.Thickness(4,3,4,0)
    $midBox = New-Object System.Windows.Controls.Border
    $midBox.BorderBrush = Get-Brush "#333842"; $midBox.BorderThickness = New-Object System.Windows.Thickness(1,0,1,0)
    $midBox.Child = $redLineM
    [System.Windows.Controls.Grid]::SetColumn($midBox, 1)

    $redLineR = New-Object System.Windows.Controls.Border
    $redLineR.Height = 2.5; $redLineR.Background = Get-Brush "#DC2626"; $redLineR.VerticalAlignment = "Bottom"; $redLineR.Margin = New-Object System.Windows.Thickness(2,0,2,2)
    [System.Windows.Controls.Grid]::SetColumn($redLineR, 2)

    $tpGrid.Children.Add($redLineL) | Out-Null
    $tpGrid.Children.Add($midBox)   | Out-Null
    $tpGrid.Children.Add($redLineR) | Out-Null
    $tpBar.Child = $tpGrid
    $KeyboardCanvas.Children.Add($tpBar) | Out-Null

    # 4. 配列連動プリセットボタンの再構築
    Rebuild-PresetButtons

    # 5. UI更新
    Update-VisualKeyboardUI
}

function Set-KeyById([string]$id, [uint32]$newCode) {
    $activeKeys = Get-ActiveVisualKeys
    $k = $activeKeys | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if ($k) {
        Set-KeyCodeForDef $k $newCode
    }
}

function Swap-KeysById([string]$id1, [string]$id2) {
    $activeKeys = Get-ActiveVisualKeys
    $k1 = $activeKeys | Where-Object { $_.Id -eq $id1 } | Select-Object -First 1
    $k2 = $activeKeys | Where-Object { $_.Id -eq $id2 } | Select-Object -First 1
    if ($k1 -and $k2) {
        $c1 = Read-UInt32LE $Global:CurrentBinBytes (Get-MatrixOffset $k1.Col $k1.Row)
        $c2 = Read-UInt32LE $Global:CurrentBinBytes (Get-MatrixOffset $k2.Col $k2.Row)
        Set-KeyCodeForDef $k1 $c2
        Set-KeyCodeForDef $k2 $c1
        Write-Log "キーを入れ替えました: $($k1.Label) ⇔ $($k2.Label)"
    }
}

function Rebuild-PresetButtons() {
    $PresetWrapPanel.Children.Clear()

    $headerTxt = New-Object System.Windows.Controls.TextBlock
    $headerTxt.Text = switch ($Global:ActiveLayout) {
        "UK" { "🇬🇧 UK版向け定番プリセット:" }
        "US" { "🇺🇸 US版向け定番プリセット:" }
        "FR" { "🇫🇷 FR版向け定番プリセット:" }
        default { "🇯🇵 JIS版向け定番プリセット:" }
    }
    $headerTxt.FontSize = 12
    $headerTxt.FontWeight = "Bold"
    $headerTxt.Foreground = Get-Brush "#1E293B"
    $headerTxt.VerticalAlignment = "Center"
    $headerTxt.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $PresetWrapPanel.Children.Add($headerTxt) | Out-Null

    # 配列ごとのプリセット定義
    $presets = @()
    if ($Global:ActiveLayout -eq "JIS") {
        $presets += @{ Label="無変換・変換 ⇒ Space"; Tip="親指スペースキーを左右に拡張します"; Action={
            Set-KeyById "Muhenkan" 0x0000002C
            Set-KeyById "Henkan"   0x0000002C
            Write-Log "プリセット適用: 無変換・変換 ⇒ Space"
        }}
        $presets += @{ Label="Fn ⇔ 左Ctrl 入替"; Tip="左下のFnとCtrlを物理的・電気的に入れ替えます"; Action={
            Swap-KeysById "Fn" "LCtrl"
        }}
        $presets += @{ Label="CapsLock ⇒ 左Ctrl"; Tip="CapsLockを左Ctrlとして動作させます"; Action={
            Set-KeyById "Caps" 0x000000E0
            Write-Log "プリセット適用: CapsLock ⇒ 左Ctrl"
        }}
        $presets += @{ Label="CapsLock ⇒ 半角/全角"; Tip="CapsLockをIME切替キーとして動作させます"; Action={
            Set-KeyById "Caps" 0x00000035
            Write-Log "プリセット適用: CapsLock ⇒ 半角/全角"
        }}
        $presets += @{ Label="PrtSc 無効化"; Tip="右下のPrtScの誤打を防止します"; Action={
            Set-KeyById "PrtSc" 0x00000000
            Write-Log "プリセット適用: PrtSc 無効化"
        }}
        $presets += @{ Label="Fn+4(スリープ) 無効化"; Tip="作業中のスリープ誤爆を防止します"; Action={
            Disable-FnSleepKey
        }}
    } elseif ($Global:ActiveLayout -eq "UK") {
        $presets += @{ Label="Fn ⇔ 左Ctrl 入替"; Tip="左下のFnとCtrlを入れ替えます"; Action={
            Swap-KeysById "Fn" "LCtrl"
        }}
        $presets += @{ Label="CapsLock ⇒ 左Ctrl"; Tip="CapsLockを左Ctrlとして動作させます"; Action={
            Set-KeyById "Caps" 0x000000E0
            Write-Log "プリセット適用: CapsLock ⇒ 左Ctrl"
        }}
        $presets += @{ Label="左Shift隣[＼ |] ⇒ 左Shift拡張"; Tip="短い左Shiftの右隣キーも左Shiftとして動作させます"; Action={
            Set-KeyById "IsoBS" 0x000000E1
            Write-Log "プリセット適用: ISO Backslash ⇒ 左Shift"
        }}
        $presets += @{ Label="左Shift隣[＼ |] ⇒ JIS [ろ (＼ _)]"; Tip="WindowsがJIS認識時に反応しないISOキーをろに変換"; Action={
            Set-KeyById "IsoBS" 0x00000087
            Write-Log "プリセット適用: ISO Backslash ⇒ JIS ろ"
        }}
        $presets += @{ Label="AltGr ⇒ 半角/全角(IME切替)"; Tip="右下のAltGrで日本語IMEのON/OFFを切替"; Action={
            Set-KeyById "RAlt" 0x00000035
            Write-Log "プリセット適用: AltGr ⇒ 半角/全角"
        }}
        $presets += @{ Label="PrtSc 無効化"; Tip="右下のPrtSc誤打防止"; Action={
            Set-KeyById "PrtSc" 0x00000000
            Write-Log "プリセット適用: PrtSc 無効化"
        }}
        $presets += @{ Label="Fn+4(スリープ) 無効化"; Tip="作業中のスリープ誤爆を防止します"; Action={
            Disable-FnSleepKey
        }}
    } elseif ($Global:ActiveLayout -eq "FR") {
        $presets += @{ Label="Fn ⇔ 左Ctrl 入替"; Tip="左下のFnとCtrlを物理的・電気的に入れ替えます"; Action={
            Swap-KeysById "Fn" "LCtrl"
        }}
        $presets += @{ Label="CapsLock ⇒ 左Ctrl"; Tip="CapsLockを左Ctrl化します"; Action={
            Set-KeyById "Caps" 0x000000E0
            Write-Log "プリセット適用: CapsLock ⇒ 左Ctrl"
        }}
        $presets += @{ Label="左Shift隣[> <] ⇒ 左Shift拡張"; Tip="短い左Shiftの右隣にある[> <]キーも左Shiftとして動作させます"; Action={
            Set-KeyById "IsoLess" 0x000000E1
            Write-Log "プリセット適用: [> <] ⇒ 左Shift"
        }}
        $presets += @{ Label="左Shift隣[> <] ⇒ JIS [ろ (＼ _)]"; Tip="WindowsがJIS認識時に反応しないISOキーをろに変換"; Action={
            Set-KeyById "IsoLess" 0x00000087
            Write-Log "プリセット適用: [> <] ⇒ JIS ろ"
        }}
        $presets += @{ Label="AltGr ⇒ 半角/全角(IME切替)"; Tip="右下のAltGrで日本語IMEのON/OFFを切替"; Action={
            Set-KeyById "RAlt" 0x00000035
            Write-Log "プリセット適用: AltGr ⇒ 半角/全角"
        }}
        $presets += @{ Label="ImpÉc (PrtSc) 無効化"; Tip="右下のImpÉc(PrtSc)の誤打を防止します"; Action={
            Set-KeyById "PrtSc" 0x00000000
            Write-Log "プリセット適用: ImpÉc (PrtSc) 無効化"
        }}
        $presets += @{ Label="Fn+4(スリープ) 無効化"; Tip="作業中のスリープ誤爆を防止します"; Action={
            Disable-FnSleepKey
        }}
    } else {
        # US配列
        $presets += @{ Label="Fn ⇔ 左Ctrl 入替"; Tip="左下のFnとCtrlを入れ替えます"; Action={
            Swap-KeysById "Fn" "LCtrl"
        }}
        $presets += @{ Label="CapsLock ⇒ 半角/全角(IME切替)"; Tip="USキーボードの定番: CapsLockで日本語入力切替"; Action={
            Set-KeyById "Caps" 0x00000035
            Write-Log "プリセット適用: CapsLock ⇒ 半角/全角"
        }}
        $presets += @{ Label="CapsLock ⇒ 左Ctrl"; Tip="Unix/Emacs風: CapsLockを左Ctrl化"; Action={
            Set-KeyById "Caps" 0x000000E0
            Write-Log "プリセット適用: CapsLock ⇒ 左Ctrl"
        }}
        $presets += @{ Label="Alt(右Alt) ⇒ 半角/全角(IME切替)"; Tip="右親指のAltキーで日本語入力切替"; Action={
            Set-KeyById "RAlt" 0x00000035
            Write-Log "プリセット適用: 右Alt ⇒ 半角/全角"
        }}
        $presets += @{ Label="PrtSc 無効化"; Tip="右下のPrtSc誤打防止"; Action={
            Set-KeyById "PrtSc" 0x00000000
            Write-Log "プリセット適用: PrtSc 無効化"
        }}
        $presets += @{ Label="Fn+4(スリープ) 無効化"; Tip="作業中のスリープ誤爆を防止します"; Action={
            Disable-FnSleepKey
        }}
    }

    foreach ($p in $presets) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $p.Label
        $btn.ToolTip = $p.Tip
        $btn.Style   = $Window.FindResource("SecondaryButton")
        $btn.Margin  = New-Object System.Windows.Thickness(0, 2, 5, 2)
        $btn.Tag = $p.Action
        $btn.Add_Click({
            param($sender, $e)
            try {
                if ($null -ne $sender.Tag) {
                    & $sender.Tag
                    Update-VisualKeyboardUI
                }
            } catch {
                Write-Log ("プリセット適用エラー: " + $_.Exception.Message)
            }
        })
        $PresetWrapPanel.Children.Add($btn) | Out-Null
    }
}

function Disable-FnSleepKey() {
    $idx = 5
    $mOff = $FN_MEDIA_OFFSET  + ($idx * 4)
    $fOff = $FN_FNLOCK_OFFSET + ($idx * 4)
    Write-UInt32LE $Global:CurrentBinBytes $mOff 0
    Write-UInt32LE $Global:CurrentBinBytes $fOff 0
    Write-Log "Fn+4 (スリープ誤爆) を無効化(0x00000000)しました。"
}

function Set-KeyCodeForDef($kDef, [uint32]$newCode) {
    $off = Get-MatrixOffset $kDef.Col $kDef.Row
    Write-UInt32LE $Global:CurrentBinBytes $off $newCode
    foreach ($dup in $kDef.DuplicateCells) {
        $dupOff = Get-MatrixOffset $dup.Col $dup.Row
        Write-UInt32LE $Global:CurrentBinBytes $dupOff $newCode
    }
}

# UK版実機キートップのビジュアル要素生成関数
function Build-KeycapVisual($k, [uint32]$currCode, [uint32]$origCode, [bool]$isSelected, [bool]$isSwapSrc) {
    $isModified = ($currCode -ne $origCode)
    $isDisabled = ($currCode -eq 0)
    $currShort  = Get-KeyShortLabel $currCode

    # カラー決定 (実機ダークチャコール基調 + 変更/無効/選択オーバーレイ)
    $bgHex     = "#23262C"
    $borderHex = "#3E4451"
    $borderThk = 1.2
    $fgMainHex = "#F8FAFC"
    $fgSubHex  = "#CBD5E1"

    if ($isDisabled) {
        $bgHex     = "#451215"
        $borderHex = "#F87171"
        $borderThk = 1.8
        $fgMainHex = "#FCA5A5"
        $fgSubHex  = "#F87171"
    } elseif ($isModified) {
        $bgHex     = "#0C4A6E"
        $borderHex = "#38BDF8"
        $borderThk = 1.8
        $fgMainHex = "#E0F2FE"
        $fgSubHex  = "#7DD3FC"
    }

    if ($isSelected -or $isSwapSrc) {
        $borderHex = "#F59E0B"
        $borderThk = 2.8
    }

    # 逆L字 (ISO/JIS) Enter キー専用描画 (角丸Path + 動的ジオメトリ)
    if ($k.Type -eq "EnterISO") {
        $rootGrid = New-Object System.Windows.Controls.Grid
        $rootGrid.Width  = $k.W
        $rootGrid.Height = $k.H

        $W  = [double]$k.W
        $H  = [double]$k.H
        $nw = if ($null -ne $k.NotchW) { [double]$k.NotchW } else { 14.0 }
        $nh = if ($null -ne $k.NotchH) { [double]$k.NotchH } else { 58.0 }

        $pathData = Get-EnterPathData $W $H $nw $nh
        $path = New-Object System.Windows.Shapes.Path
        $path.Data = [System.Windows.Media.Geometry]::Parse($pathData)
        $path.Fill = Get-Brush $bgHex
        $path.Stroke = Get-Brush $borderHex
        $path.StrokeThickness = $borderThk
        $path.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
        $rootGrid.Children.Add($path) | Out-Null

        # 刻印表示 (上段中央に配置)
        $lblStack = New-Object System.Windows.Controls.StackPanel
        $lblStack.HorizontalAlignment = "Center"
        $lblStack.VerticalAlignment   = "Top"

        $enterText = if ($null -ne $k.Text -and $k.Text -ne "") { $k.Text } else { "Enter" }
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = $enterText
        if ($enterText -eq "Enter") {
            $t1.FontSize = 12.5
            $t1.FontWeight = "Bold"
            $lblStack.Margin = New-Object System.Windows.Thickness(0, 18, 0, 0)
        } else {
            # "↵" など記号
            $t1.FontSize = 19
            $t1.FontWeight = "Bold"
            $lblStack.Margin = New-Object System.Windows.Thickness(0, 11, 0, 0)
        }
        $t1.HorizontalAlignment = "Center"
        $t1.Foreground = Get-Brush $fgMainHex
        $lblStack.Children.Add($t1) | Out-Null

        if ($isDisabled) {
            $b = New-Object System.Windows.Controls.TextBlock
            $b.Text = "× 無効"
            $b.FontSize = 10; $b.FontWeight = "Bold"; $b.Foreground = Get-Brush "#FCA5A5"
            $b.HorizontalAlignment = "Center"
            $b.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
            $lblStack.Children.Add($b) | Out-Null
        } elseif ($isModified) {
            $b = New-Object System.Windows.Controls.TextBlock
            $b.Text = "⇒ $currShort"
            $b.FontSize = 10; $b.FontWeight = "Bold"; $b.Foreground = Get-Brush "#38BDF8"
            $b.HorizontalAlignment = "Center"
            $b.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
            $lblStack.Children.Add($b) | Out-Null
        }
        $rootGrid.Children.Add($lblStack) | Out-Null
        return $rootGrid
    }

    # 通常キー / Fnキー / 半高キー用の ThinkPad スマイルシェイプ Border
    $corner = if ($k.Type -eq "FnRow" -or $k.Type -eq "Half") {
        New-Object System.Windows.CornerRadius(3, 3, 6, 6)
    } else {
        New-Object System.Windows.CornerRadius(4, 4, 9, 9)
    }

    $bd = New-Object System.Windows.Controls.Border
    $bd.Width           = $k.W
    $bd.Height          = $k.H
    $bd.Background      = Get-Brush $bgHex
    $bd.BorderBrush     = Get-Brush $borderHex
    $bd.BorderThickness = New-Object System.Windows.Thickness($borderThk)
    $bd.CornerRadius    = $corner
    $bd.Padding         = New-Object System.Windows.Thickness(5, 3, 5, 3)

    $grid = New-Object System.Windows.Controls.Grid

    if ($k.Type -eq "FnRow") {
        if ($k.TL -ne "") {
            # Esc (FnLock)
            $tTL = New-Object System.Windows.Controls.TextBlock
            $tTL.Text = $k.TL; $tTL.FontSize = 11; $tTL.FontWeight = "Bold"
            $tTL.Foreground = Get-Brush $fgMainHex
            $tTL.HorizontalAlignment = "Left"; $tTL.VerticalAlignment = "Top"
            $grid.Children.Add($tTL) | Out-Null

            $tBL = New-Object System.Windows.Controls.TextBlock
            $tBL.Text = $k.BL; $tBL.FontSize = 8.5
            $tBL.Foreground = Get-Brush $fgSubHex
            $tBL.HorizontalAlignment = "Left"; $tBL.VerticalAlignment = "Bottom"
            $grid.Children.Add($tBL) | Out-Null
        } else {
            # F1..F12, Home, End, Delete
            $tIcon = New-Object System.Windows.Controls.TextBlock
            $tIcon.Text = $k.Icon
            $tIcon.FontSize = $(if ($k.Sub -eq "") { 10.5 } else { 10 })
            $tIcon.Foreground = Get-Brush $fgMainHex
            $tIcon.HorizontalAlignment = "Center"
            $tIcon.VerticalAlignment   = $(if ($k.Sub -eq "") { "Center" } else { "Top" })
            $grid.Children.Add($tIcon) | Out-Null

            if ($k.Sub -ne "") {
                $tSub = New-Object System.Windows.Controls.TextBlock
                $tSub.Text = $k.Sub; $tSub.FontSize = 8.5
                $tSub.Foreground = Get-Brush $fgSubHex
                $tSub.HorizontalAlignment = "Center"; $tSub.VerticalAlignment = "Bottom"
                $grid.Children.Add($tSub) | Out-Null
            }
        }
    } elseif ($k.Type -eq "Half") {
        $tC = New-Object System.Windows.Controls.TextBlock
        $tC.Text = $k.Text; $tC.FontSize = 10.5; $tC.FontWeight = "Bold"
        $tC.Foreground = Get-Brush $fgMainHex
        $tC.HorizontalAlignment = "Center"; $tC.VerticalAlignment = "Center"
        $grid.Children.Add($tC) | Out-Null
    } elseif ($k.Type -eq "Mod") {
        if ($k.TL -ne "") {
            $tTL = New-Object System.Windows.Controls.TextBlock
            $tTL.Text = $k.TL
            $tTL.FontSize = $(if ($k.Id -eq "LShift") { 15 } elseif ($k.Id -eq "Tab") { 12 } else { 11.5 })
            $tTL.Foreground = Get-Brush $fgMainHex
            $tTL.HorizontalAlignment = "Left"
            $tTL.VerticalAlignment   = $(if ($k.Id -eq "LShift" -or $k.Id -eq "Fn" -or $k.Id -eq "LCtrl" -or $k.Id -eq "LAlt" -or $k.Id -eq "RAlt" -or $k.Id -eq "RCtrl") { "Center" } else { "Top" })
            $tTL.Margin = New-Object System.Windows.Thickness(3, 1, 0, 0)
            $grid.Children.Add($tTL) | Out-Null
        }
        if ($k.TR -ne "") {
            $tTR = New-Object System.Windows.Controls.TextBlock
            $tTR.Text = $k.TR
            $tTR.FontSize = $(if ($k.Id -eq "RShift" -or $k.Id -eq "BS") { 15 } else { 11.5 })
            $tTR.Foreground = Get-Brush $fgMainHex
            $tTR.HorizontalAlignment = "Right"
            $tTR.VerticalAlignment   = $(if ($k.Id -eq "RShift") { "Center" } else { "Top" })
            $tTR.Margin = New-Object System.Windows.Thickness(0, 1, 4, 0)
            $grid.Children.Add($tTR) | Out-Null
        }
        if ($k.ML -ne "") {
            $tML = New-Object System.Windows.Controls.TextBlock
            $tML.Text = $k.ML
            $tML.FontSize = $(if ($k.Id -eq "LWin") { 16 } elseif ($k.Id -eq "Tab") { 12 } else { 11.5 })
            $tML.Foreground = Get-Brush $fgMainHex
            $tML.HorizontalAlignment = $(if ($k.Id -eq "LWin") { "Center" } else { "Left" })
            $tML.VerticalAlignment   = $(if ($k.Id -eq "Tab") { "Bottom" } else { "Center" })
            $tML.Margin = New-Object System.Windows.Thickness(3, 0, 0, 2)
            $grid.Children.Add($tML) | Out-Null
        }
        if ($k.BL -ne "") {
            $tBL = New-Object System.Windows.Controls.TextBlock
            $tBL.Text = $k.BL
            $tBL.FontSize = 10.5
            $tBL.Foreground = Get-Brush $fgSubHex
            $tBL.HorizontalAlignment = $(if ($k.Id -eq "PrtSc") { "Center" } else { "Left" })
            $tBL.VerticalAlignment = "Bottom"
            $tBL.Margin = New-Object System.Windows.Thickness(3, 0, 0, 1)
            $grid.Children.Add($tBL) | Out-Null
        }
    } else {
        # 標準UKキー (アルファベットは左上大文字、数字/記号は上下2段＋右下ユーロ記号等)
        if ($k.TL -ne "") {
            $tTL = New-Object System.Windows.Controls.TextBlock
            $tTL.Text = $k.TL
            $tTL.FontSize = $(if ($k.BL -ne "" -and $k.BL -ne "_") { 11.5 } else { 14.5 })
            $tTL.FontWeight = "Bold"
            $tTL.Foreground = Get-Brush $fgMainHex
            $tTL.HorizontalAlignment = "Left"; $tTL.VerticalAlignment = "Top"
            $tTL.Margin = $(if ($k.Id -eq "B") { New-Object System.Windows.Thickness(6, 15, 0, 0) } else { New-Object System.Windows.Thickness(3, 1, 0, 0) })
            $grid.Children.Add($tTL) | Out-Null
        }
        if ($k.BL -ne "") {
            $tBL = New-Object System.Windows.Controls.TextBlock
            $tBL.Text = $k.BL
            $tBL.FontSize = $(if ($k.BL -eq "_") { 12 } else { 13.5 })
            $tBL.FontWeight = "Bold"
            $tBL.Foreground = Get-Brush $fgMainHex
            $tBL.HorizontalAlignment = $(if ($k.BL -eq "_") { "Center" } else { "Left" })
            $tBL.VerticalAlignment = "Bottom"
            $tBL.Margin = New-Object System.Windows.Thickness(3, 0, 0, 1)
            $grid.Children.Add($tBL) | Out-Null
        }
        if ($k.BR -ne "") {
            $tBR = New-Object System.Windows.Controls.TextBlock
            $tBR.Text = $k.BR; $tBR.FontSize = 11.5; $tBR.FontWeight = "Bold"
            $tBR.Foreground = Get-Brush $fgSubHex
            $tBR.HorizontalAlignment = "Right"; $tBR.VerticalAlignment = "Bottom"
            $tBR.Margin = New-Object System.Windows.Thickness(0, 0, 3, 1)
            $grid.Children.Add($tBR) | Out-Null
        }
    }

    # 変更済・無効化時のオーバーレイバッジ
    if ($isDisabled -or $isModified) {
        $badge = New-Object System.Windows.Controls.Border
        $badge.CornerRadius = New-Object System.Windows.CornerRadius(3)
        $badge.Padding      = New-Object System.Windows.Thickness(3, 1, 3, 1)
        $badge.HorizontalAlignment = "Center"
        $badge.VerticalAlignment   = "Bottom"
        $badge.Background = Get-Brush $(if ($isDisabled) { "#DC2626" } else { "#0284C7" })

        $bTxt = New-Object System.Windows.Controls.TextBlock
        $bTxt.Text       = $(if ($isDisabled) { "×無効" } else { "⇒$currShort" })
        $bTxt.FontSize   = $(if ($k.Type -eq "FnRow" -or $k.Type -eq "Half") { 8.5 } else { 9.5 })
        $bTxt.FontWeight = "Bold"
        $bTxt.Foreground = [System.Windows.Media.Brushes]::White
        $badge.Child = $bTxt
        $grid.Children.Add($badge) | Out-Null
    }

    $bd.Child = $grid
    return $bd
}

function Update-VisualKeyboardUI() {
    $diffLines = New-Object System.Collections.Generic.List[string]
    $changeCount = 0

    $activeKeys = Get-ActiveVisualKeys
    foreach ($k in $activeKeys) {
        if ($Global:KeyButtons.ContainsKey($k.Id)) {
            $btn = $Global:KeyButtons[$k.Id]
        $off = Get-MatrixOffset $k.Col $k.Row
        $currCode = Read-UInt32LE $Global:CurrentBinBytes $off
        $origCode = Read-UInt32LE $Global:OrigBinBytes $off

        $isSelected = ($null -ne $Global:SelectedKey -and $Global:SelectedKey.Id -eq $k.Id)
        $isSwapSrc  = ($null -ne $Global:SwapSourceKey -and $Global:SwapSourceKey.Id -eq $k.Id)

        $btn.Content = Build-KeycapVisual $k $currCode $origCode $isSelected $isSwapSrc
        }
    }

    # マトリクス全体の差分集計
    for ($c = 0; $c -lt 16; $c++) {
        for ($r = 0; $r -lt 8; $r++) {
            $o = Get-MatrixOffset $c $r
            $cv = Read-UInt32LE $Global:CurrentBinBytes $o
            $ov = Read-UInt32LE $Global:OrigBinBytes $o
            if ($cv -ne $ov) {
                $changeCount++
                $diffLines.Add(("[通常マトリクス] Offset 0x{0:X4} (Col={1,2}, Row={2}): {3} -> {4}" -f $o, $c, $r, (Get-KeyFullName $ov), (Get-KeyFullName $cv)))
            }
        }
    }

    # Fnレイヤーの差分集計＆テーブル更新
    $fnRows = New-Object System.Collections.Generic.List[PSObject]
    foreach ($fnDef in $FnLayerDefinitions) {
        $idx = $fnDef.Index
        $mOff = $FN_MEDIA_OFFSET  + ($idx * 4)
        $fOff = $FN_FNLOCK_OFFSET + ($idx * 4)
        $mCurr = Read-UInt32LE $Global:CurrentBinBytes $mOff
        $mOrig = Read-UInt32LE $Global:OrigBinBytes    $mOff
        $fCurr = Read-UInt32LE $Global:CurrentBinBytes $fOff
        $fOrig = Read-UInt32LE $Global:OrigBinBytes    $fOff

        $st = "標準"
        if ($mCurr -eq 0 -and $fCurr -eq 0) {
            $st = "無効化"
        } elseif ($mCurr -ne $mOrig -or $fCurr -ne $fOrig) {
            $st = "変更済"
        }

        if ($mCurr -ne $mOrig) {
            $changeCount++
            $diffLines.Add(("[Fnメディア枠]   Offset 0x{0:X4} ({1}): 0x{2:X8} -> 0x{3:X8}" -f $mOff, $fnDef.KeyName, $mOrig, $mCurr))
        }
        if ($fCurr -ne $fOrig) {
            $changeCount++
            $diffLines.Add(("[FnLock枠]       Offset 0x{0:X4} ({1}): 0x{2:X8} -> 0x{3:X8}" -f $fOff, $fnDef.KeyName, $fOrig, $fCurr))
        }

        $fnRows.Add([PSCustomObject]@{
            Index     = $idx
            KeyName   = $fnDef.KeyName
            Desc      = $fnDef.Desc
            MediaHex  = Format-FnActionValue $mCurr
            FnLockHex = Format-FnActionValue $fCurr
            Status    = $st
            Def       = $fnDef
        })
    }
    $selIdx = $GridFnLayer.SelectedIndex
    $GridFnLayer.ItemsSource = $fnRows
    if ($selIdx -ge 0 -and $selIdx -lt $fnRows.Count) {
        $GridFnLayer.SelectedIndex = $selIdx
    }

    # 選択中キーの詳細パネル更新
    if ($null -ne $Global:SelectedKey) {
        $k = $Global:SelectedKey
        $off = Get-MatrixOffset $k.Col $k.Row
        $currCode = Read-UInt32LE $Global:CurrentBinBytes $off
        $origCode = Read-UInt32LE $Global:OrigBinBytes $off

        $TxtSelKeyTitle.Text = "【$($k.Label)】 キー"
        $TxtSelCoord.Text    = ("Col={0}, Row={1} (ROM Offset: 0x{2:X4})" -f $k.Col, $k.Row, $off)
        $TxtSelOrigCode.Text = Get-KeyFullName $origCode
        $TxtSelCurrCode.Text = Get-KeyFullName $currCode
        $TxtCustomHex.Text   = ("0x{0:X8}" -f $currCode)

        for ($i = 0; $i -lt $HidKeyCatalog.Count; $i++) {
            if ($HidKeyCatalog[$i].Code -eq $currCode) {
                $CmbTargetKey.SelectedIndex = $i
                break
            }
        }
    }

    # 差分テキストとフッター更新
    $sum64 = [uint64]0
    foreach ($b in $Global:CurrentBinBytes) { $sum64 += $b }
    $checksum16 = [uint16]($sum64 -band 0xFFFF)

    $TxtFooterSummary.Text = ("純正からの変更数: {0} 箇所  |  現在のROMチェックサム(16bit): 0x{1:X4}" -f $changeCount, $checksum16)
    if ($diffLines.Count -eq 0) {
        $TxtDiffPreview.Text = "（現在、純正ファームウェアからの変更箇所はありません）"
    } else {
        $TxtDiffPreview.Text = ($diffLines -join "`r`n")
    }

    $bakBinExists = Test-Path $BinBak
    $bakIspExists = Test-Path $IspBak
    $TxtBackupStatus.Text = "・ファームウェア原本バックアップ: " + ($(if ($bakBinExists) { "保存済 ($BinBak)" } else { "未作成" })) + "`r`n" +
                            "・KB-ISP.exe 原本バックアップ: " + ($(if ($bakIspExists) { "保存済 ($IspBak)" } else { "未作成" }))
}

function On-KeyButtonClicked($kDef) {
    if ($null -ne $Global:SwapSourceKey) {
        $src = $Global:SwapSourceKey
        $Global:SwapSourceKey = $null
        $BtnStartSwap.Content = "他のキーと入れ替える (Swapモード)"

        if ($src.Id -ne $kDef.Id) {
            $off1 = Get-MatrixOffset $src.Col $src.Row
            $off2 = Get-MatrixOffset $kDef.Col $kDef.Row
            $val1 = Read-UInt32LE $Global:CurrentBinBytes $off1
            $val2 = Read-UInt32LE $Global:CurrentBinBytes $off2

            Set-KeyCodeForDef $src  $val2
            Set-KeyCodeForDef $kDef $val1
            Write-Log ("キー入れ替え(Swap): 【{0}】({1}) ⇔ 【{2}】({3})" -f $src.Label, (Get-KeyShortLabel $val1), $kDef.Label, (Get-KeyShortLabel $val2))
        }
    }

    $Global:SelectedKey = $kDef
    Update-VisualKeyboardUI
}

# イベントハンドラ登録
# 配列切り替え処理および ComboBox ハンドラ
function Switch-KeyboardLayout([string]$layoutName) {
    $Global:ActiveLayout = $layoutName
    $targetIndex = switch ($layoutName) {
        "UK" { 1 }
        "US" { 2 }
        "FR" { 3 }
        default { 0 }
    }
    if ($CmbLayout -and $CmbLayout.SelectedIndex -ne $targetIndex) {
        $CmbLayout.SelectedIndex = $targetIndex
    }

    switch ($layoutName) {
        "UK" {
            if ($TxtKeyboardTitle) { $TxtKeyboardTitle.Text = "英語 (UK / ISO 84キー) 配列（クリックして選択/入替）" }
            Write-Log "キーボードレイアウトを【🇬🇧 英語 UK / ISO (84キー)】に切り替えました。"
        }
        "US" {
            if ($TxtKeyboardTitle) { $TxtKeyboardTitle.Text = "英語 (US / ANSI 83キー) 配列（クリックして選択/入替）" }
            Write-Log "キーボードレイアウトを【🇺🇸 英語 US / ANSI (83キー)】に切り替えました。"
        }
        "FR" {
            if ($TxtKeyboardTitle) { $TxtKeyboardTitle.Text = "フランス語 (FR / AZERTY 84キー) 配列（クリックして選択/入替）" }
            Write-Log "キーボードレイアウトを【🇫🇷 フランス語 FR / AZERTY (84キー)】に切り替えました。"
        }
        default {
            if ($TxtKeyboardTitle) { $TxtKeyboardTitle.Text = "日本語 (JIS 88キー) 配列（クリックして選択/入替）" }
            Write-Log "キーボードレイアウトを【🇯🇵 日本語 JIS (88キー)】に切り替えました。"
        }
    }
    Rebuild-KeyboardCanvas
}

if ($CmbLayout) {
    $CmbLayout.Add_SelectionChanged({
        if ($CmbLayout.SelectedItem) {
            $tag = $CmbLayout.SelectedItem.Tag
            if ($tag -and $tag -ne $Global:ActiveLayout) {
                Switch-KeyboardLayout $tag
            }
        }
    })
}

$BtnApplyKey.Add_Click({
    if ($null -eq $Global:SelectedKey) {
        [System.Windows.MessageBox]::Show("先に左側のキーボード図から変更したいキーをクリックして選択してください。", "案内", "OK", "Information") | Out-Null
        return
    }
    $idx = $CmbTargetKey.SelectedIndex
    if ($idx -lt 0) { return }
    $targetItem = $HidKeyCatalog[$idx]
    Set-KeyCodeForDef $Global:SelectedKey $targetItem.Code
    Write-Log ("キー変更: 【{0}】 ⇒ {1} (0x{2:X8})" -f $Global:SelectedKey.Label, $targetItem.Name, $targetItem.Code)
    Update-VisualKeyboardUI
})

$BtnDisableKey.Add_Click({
    if ($null -eq $Global:SelectedKey) {
        [System.Windows.MessageBox]::Show("先に左側のキーボード図から無効化したいキーを選択してください。", "案内", "OK", "Information") | Out-Null
        return
    }
    Set-KeyCodeForDef $Global:SelectedKey 0x00000000
    Write-Log ("キー無効化: 【{0}】 ⇒ 無効 (0x00000000)" -f $Global:SelectedKey.Label)
    Update-VisualKeyboardUI
})

$BtnRestoreKey.Add_Click({
    if ($null -eq $Global:SelectedKey) { return }
    $off = Get-MatrixOffset $Global:SelectedKey.Col $Global:SelectedKey.Row
    $origVal = Read-UInt32LE $Global:OrigBinBytes $off
    Set-KeyCodeForDef $Global:SelectedKey $origVal
    Write-Log ("キー復元: 【{0}】 ⇒ 純正初期値 ({1})" -f $Global:SelectedKey.Label, (Get-KeyFullName $origVal))
    Update-VisualKeyboardUI
})

$BtnStartSwap.Add_Click({
    if ($null -eq $Global:SelectedKey) {
        [System.Windows.MessageBox]::Show("先に入れ替え元のキーを1つ選択してください。", "案内", "OK", "Information") | Out-Null
        return
    }
    if ($null -eq $Global:SwapSourceKey) {
        $Global:SwapSourceKey = $Global:SelectedKey
        $BtnStartSwap.Content = "【入替先キーをクリックしてください (キャンセルは再クリック)】"
        Write-Log ("入れ替え(Swap)待機中: 【{0}】と入れ替える相手のキーを左図からクリックしてください。" -f $Global:SelectedKey.Label)
    } else {
        $Global:SwapSourceKey = $null
        $BtnStartSwap.Content = "他のキーと入れ替える (Swapモード)"
        Write-Log "入れ替え(Swap)モードをキャンセルしました。"
    }
    Update-VisualKeyboardUI
})

$BtnApplyHex.Add_Click({
    if ($null -eq $Global:SelectedKey) { return }
    $txt = $TxtCustomHex.Text.Trim()
    try {
        $val = [Convert]::ToUInt32($txt, 16)
        Set-KeyCodeForDef $Global:SelectedKey $val
        Write-Log ("カスタムHEX適用: 【{0}】 ⇒ 0x{1:X8}" -f $Global:SelectedKey.Label, $val)
        Update-VisualKeyboardUI
    } catch {
        [System.Windows.MessageBox]::Show("16進数(例: 0x00000004)の形式が正しくありません。", "入力エラー", "OK", "Warning") | Out-Null
    }
})

# Fnレイヤータブ操作
$GridFnLayer.Add_SelectionChanged({
    $sel = $GridFnLayer.SelectedItem
    if ($null -ne $sel) {
        $TxtFnSelTitle.Text = "$($sel.KeyName) (Index $($sel.Index))"
        $TxtFnSelDesc.Text  = $sel.Desc
    }
})

$BtnFnApplyBoth.Add_Click({
    $sel = $GridFnLayer.SelectedItem
    if ($null -eq $sel) { return }
    $p = $FnActionPresets[$CmbFnPreset.SelectedIndex]
    $idx = $sel.Index
    Write-UInt32LE $Global:CurrentBinBytes ($FN_MEDIA_OFFSET  + $idx * 4) $p.Value
    Write-UInt32LE $Global:CurrentBinBytes ($FN_FNLOCK_OFFSET + $idx * 4) $p.Value
    Write-Log ("Fnレイヤー変更 (両方): {0} ⇒ {1}" -f $sel.KeyName, $p.Label)
    Update-VisualKeyboardUI
})

$BtnFnApplyMedia.Add_Click({
    $sel = $GridFnLayer.SelectedItem
    if ($null -eq $sel) { return }
    $p = $FnActionPresets[$CmbFnPreset.SelectedIndex]
    $idx = $sel.Index
    Write-UInt32LE $Global:CurrentBinBytes ($FN_MEDIA_OFFSET + $idx * 4) $p.Value
    Write-Log ("Fnメディア枠変更: {0} ⇒ {1}" -f $sel.KeyName, $p.Label)
    Update-VisualKeyboardUI
})

$BtnFnApplyFnLock.Add_Click({
    $sel = $GridFnLayer.SelectedItem
    if ($null -eq $sel) { return }
    $p = $FnActionPresets[$CmbFnPreset.SelectedIndex]
    $idx = $sel.Index
    Write-UInt32LE $Global:CurrentBinBytes ($FN_FNLOCK_OFFSET + $idx * 4) $p.Value
    Write-Log ("FnLock枠変更: {0} ⇒ {1}" -f $sel.KeyName, $p.Label)
    Update-VisualKeyboardUI
})

$BtnFnDisable.Add_Click({
    $sel = $GridFnLayer.SelectedItem
    if ($null -eq $sel) { return }
    $idx = $sel.Index
    Write-UInt32LE $Global:CurrentBinBytes ($FN_MEDIA_OFFSET  + $idx * 4) 0x00000000
    Write-UInt32LE $Global:CurrentBinBytes ($FN_FNLOCK_OFFSET + $idx * 4) 0x00000000
    Write-Log ("Fn組み合わせ無効化: {0} ⇒ 無効 (0x00000000)" -f $sel.KeyName)
    Update-VisualKeyboardUI
})

$BtnFnRestore.Add_Click({
    $sel = $GridFnLayer.SelectedItem
    if ($null -eq $sel) { return }
    $idx = $sel.Index
    $mOff = $FN_MEDIA_OFFSET  + $idx * 4
    $fOff = $FN_FNLOCK_OFFSET + $idx * 4
    Write-UInt32LE $Global:CurrentBinBytes $mOff (Read-UInt32LE $Global:OrigBinBytes $mOff)
    Write-UInt32LE $Global:CurrentBinBytes $fOff (Read-UInt32LE $Global:OrigBinBytes $fOff)
    Write-Log ("Fn組み合わせ復元: {0} ⇒ 純正初期値" -f $sel.KeyName)
    Update-VisualKeyboardUI
})

$BtnFnF1F12Standard.Add_Click({
    for ($i = 0; $i -lt 12; $i++) {
        $idx = 5 + $i
        $stdCode = [uint32]((0x3A + $i) -shl 8)
        Write-UInt32LE $Global:CurrentBinBytes ($FN_MEDIA_OFFSET  + $idx * 4) $stdCode
        Write-UInt32LE $Global:CurrentBinBytes ($FN_FNLOCK_OFFSET + $idx * 4) $stdCode
    }
    Write-Log "Fnレイヤー一括設定: F1〜F12 を FnLock 状態に関わらず常に標準 F1〜F12 として動作するように設定しました。"
    Update-VisualKeyboardUI
})

# JSONエクスポート・インポート
$BtnExportJson.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "Keymap Profile (*.json)|*.json"
    $dlg.FileName = "X12_Keymap_UK_Custom.json"
    $dlg.InitialDirectory = $ScriptDir
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $matrixArr = @()
        for ($i = 0; $i -lt 128; $i++) {
            $matrixArr += Read-UInt32LE $Global:CurrentBinBytes ($MATRIX_OFFSET + $i * 4)
        }
        $fnMediaArr = @()
        $fnLockArr  = @()
        for ($i = 0; $i -lt 32; $i++) {
            $fnMediaArr += Read-UInt32LE $Global:CurrentBinBytes ($FN_MEDIA_OFFSET  + $i * 4)
            $fnLockArr  += Read-UInt32LE $Global:CurrentBinBytes ($FN_FNLOCK_OFFSET + $i * 4)
        }
        $obj = [PSCustomObject]@{
            Model      = "ThinkPad X12 Detachable Gen 1 Folio Keyboard (UK Edition)"
            Version    = "v39_UT0N"
            Matrix128  = $matrixArr
            FnMedia32  = $fnMediaArr
            FnLock32   = $fnLockArr
        }
        $obj | ConvertTo-Json -Depth 4 | Set-Content -Path $dlg.FileName -Encoding UTF8
        Write-Log "設定プロファイルをJSONに保存しました: $($dlg.FileName)"
    }
})

$BtnImportJson.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Keymap Profile (*.json)|*.json"
    $dlg.InitialDirectory = $ScriptDir
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $obj = Get-Content -Path $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($obj.Matrix128.Count -eq 128) {
                for ($i = 0; $i -lt 128; $i++) {
                    Write-UInt32LE $Global:CurrentBinBytes ($MATRIX_OFFSET + $i * 4) ([uint32]$obj.Matrix128[$i])
                }
            }
            if ($obj.FnMedia32.Count -eq 32) {
                for ($i = 0; $i -lt 32; $i++) {
                    Write-UInt32LE $Global:CurrentBinBytes ($FN_MEDIA_OFFSET + $i * 4) ([uint32]$obj.FnMedia32[$i])
                }
            }
            if ($obj.FnLock32.Count -eq 32) {
                for ($i = 0; $i -lt 32; $i++) {
                    Write-UInt32LE $Global:CurrentBinBytes ($FN_FNLOCK_OFFSET + $i * 4) ([uint32]$obj.FnLock32[$i])
                }
            }
            if ($null -ne $obj.ActiveLayout) {
                Switch-KeyboardLayout $obj.ActiveLayout
            }
            Write-Log "設定プロファイルをJSONから読み込みました: $($dlg.FileName)"
            Update-VisualKeyboardUI
        } catch {
            [System.Windows.MessageBox]::Show("JSONファイルの読み込みに失敗しました:`n$($_.Exception.Message)", "エラー", "OK", "Error") | Out-Null
        }
    }
})

# すべて純正初期状態に復元
$BtnRestoreAllOrig.Add_Click({
    $res = [System.Windows.MessageBox]::Show("すべてのキー設定および KB-ISP.exe を純正の初期状態（バックアップ）に復元しますか？", "純正状態への復元確認", "YesNo", "Question")
    if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $Global:CurrentBinBytes = [byte[]]$Global:OrigBinBytes.Clone()
    [System.IO.File]::WriteAllBytes($BinPath, $Global:CurrentBinBytes)
    if (Test-Path $IspBak) {
        Copy-Item -Path $IspBak -Destination $IspPath -Force
    }
    $ChkDisableReboot.IsChecked  = $false
    $ChkSkipPowerCheck.IsChecked = $false
    $ChkSkipVersionCheck.IsChecked = $false
    Write-Log "ファームウェアおよび KB-ISP.exe を純正バックアップから完全に復元しました。"
    Update-VisualKeyboardUI
})

function Save-PatchedFiles() {
    # 1. FW\Hera_KB_APROM_v39_UT0N.bin の保存
    [System.IO.File]::WriteAllBytes($BinPath, $Global:CurrentBinBytes)
    Write-Log "ファームウェアバイナリを保存しました: $BinPath (24,624 bytes)"

    # 2. KB-ISP.exe の同期パッチ
    if (Test-Path $IspPath) {
        [byte[]]$ispBytes = if (Test-Path $IspBak) { [System.IO.File]::ReadAllBytes($IspBak) } else { [System.IO.File]::ReadAllBytes($IspPath) }

        # 埋め込みファームウェア (0x23B630..0x24165F) を同期更新
        [System.Array]::Copy($Global:CurrentBinBytes, 0, $ispBytes, $ISP_EMBED_BIN_OFF, $EXPECTED_BIN_SIZE)
        Write-Log "KB-ISP.exe 内の埋め込みファームウェア領域 (0x23B630) を同期更新しました。"

        # PC強制再起動 (shutdown -f -r -t 0) の無効化パッチ (0x0187AC: 13 bytes)
        if ($ChkDisableReboot.IsChecked) {
            for ($i = 0; $i -lt 13; $i++) { $ispBytes[$ISP_SHUTDOWN_OFF + $i] = 0x90 }
            Write-Log "KB-ISP.exe パッチ適用: 更新後のPC強制再起動 (0x0187AC) を無効化 (NOP) しました。"
        } else {
            [System.Array]::Copy($ORIG_SHUTDOWN_BYTES, 0, $ispBytes, $ISP_SHUTDOWN_OFF, 13)
        }

        # AC電源・バッテリー残量25%チェックのスキップパッチ (0x01CCD0: 20 bytes)
        if ($ChkSkipPowerCheck.IsChecked) {
            for ($i = 0; $i -lt 20; $i++) { $ispBytes[$ISP_POWERCHK_OFF + $i] = 0x90 }
            Write-Log "KB-ISP.exe パッチ適用: AC電源・バッテリー残量チェック (0x01CCD0) をスキップ (NOP) しました。"
        } else {
            [System.Array]::Copy($ORIG_POWERCHK_BYTES, 0, $ispBytes, $ISP_POWERCHK_OFF, 20)
        }

        # バージョンチェック (同一/過去バージョンの上書き禁止) の無効化パッチ (0x01CCB6: 2 bytes: 74 18 -> EB 18)
        if ($ChkSkipVersionCheck.IsChecked) {
            $ispBytes[$ISP_VERCHK_OFF]     = 0xEB
            $ispBytes[$ISP_VERCHK_OFF + 1] = 0x18
            Write-Log "KB-ISP.exe パッチ適用: バージョンチェック (0x01CCB6: 74 18 -> EB 18) を無効化しました (何度でも上書き再書き込み可能)。"
        } else {
            [System.Array]::Copy($ORIG_VERCHK_BYTES, 0, $ispBytes, $ISP_VERCHK_OFF, 2)
        }

        [System.IO.File]::WriteAllBytes($IspPath, $ispBytes)
        Write-Log "KB-ISP.exe の保存が完了しました: $IspPath"
    }
}

$BtnSavePatch.Add_Click({
    try {
        Save-PatchedFiles
        [System.Windows.MessageBox]::Show("カスタムファームウェアおよび KB-ISP.exe へのパッチ適用が完了しました！`n`n同じフォルダー内にある『KB-ISP.exe』を起動してキーボードへ書き込みを行ってください。", "保存およびパッチ完了", "OK", "Information") | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("保存中にエラーが発生しました:`n$($_.Exception.Message)", "エラー", "OK", "Error") | Out-Null
    }
})

# 初期化実行 (初期状態 JIS)
$Global:ActiveLayout = "JIS"
if ($CmbLayout) { $CmbLayout.SelectedIndex = 0 }
Rebuild-KeyboardCanvas
$Global:SelectedKey = (Get-ActiveVisualKeys) | Where-Object { $_.Id -eq "Caps" } | Select-Object -First 1
Update-VisualKeyboardUI
Write-Log "ThinkPad X12 Detachable Gen 1 キーボード用ファームウェア キー入れ替え・無効化ツールを起動しました。対象: $BinPath"

$Window.ShowDialog() | Out-Null
