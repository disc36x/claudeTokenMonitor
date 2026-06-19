$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$inv = [Globalization.CultureInfo]::InvariantCulture

$creds = Join-Path $env:USERPROFILE '.claude\.credentials.json'
$root  = Join-Path $env:USERPROFILE '.claude\projects'
$rx    = [regex]'"input_tokens":(\d+),"cache_creation_input_tokens":(\d+),"cache_read_input_tokens":(\d+),"output_tokens":(\d+)'
$idRx  = [regex]'"id":"(msg_[^"]+)"'   # API message id; same msg is logged on multiple lines, dedupe on it

function Fmt($n) {
  if ($n -ge 1e9) { '{0:N2}B' -f ($n/1e9) }
  elseif ($n -ge 1e6) { '{0:N1}M' -f ($n/1e6) }
  elseif ($n -ge 1e3) { '{0:N1}k' -f ($n/1e3) }
  else { "$n" }
}
function ResetText($iso) {
  if (-not $iso) { return '' }
  $d = [datetimeoffset]::Parse($iso).LocalDateTime
  if ($d.Date -eq (Get-Date).Date) { 'Resets ' + $d.ToString('h:mm tt', $inv) }
  else { 'Resets ' + $d.ToString('MMM d', $inv) }
}
# Official usage from the same endpoint /usage uses (token read fresh each poll, so Claude Code's refresh is picked up)
function Get-Usage {
  $tok = (Get-Content $creds -Raw | ConvertFrom-Json).claudeAiOauth.accessToken
  if (-not $tok) { return $null }
  $h = @{ Authorization = "Bearer $tok"; 'anthropic-beta' = 'oauth-2025-04-20'; 'anthropic-version' = '2023-06-01' }
  Invoke-RestMethod -Uri 'https://api.anthropic.com/api/oauth/usage' -Headers $h -TimeoutSec 8
}
# This-session token breakdown from the most recently active transcript (endpoint doesn't provide it)
function Session-Breakdown {
  $cur = Get-ChildItem -Path $root -Recurse -Filter *.jsonl -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $seen = @{}   # message.id -> [in, cw, cr, out]; last write wins (dedupes repeated log lines)
  if ($cur) {
    switch -File $cur.FullName {
      default {
        $m = $rx.Match($_); if (-not $m.Success) { continue }
        $im = $idRx.Match($_); $id = if ($im.Success) { $im.Groups[1].Value } else { [string]$_.GetHashCode() }
        $seen[$id] = @([int64]$m.Groups[1].Value, [int64]$m.Groups[2].Value, [int64]$m.Groups[3].Value, [int64]$m.Groups[4].Value)
      }
    }
  }
  $in=[int64]0; $cw=[int64]0; $cr=[int64]0; $out=[int64]0
  foreach ($v in $seen.Values) { $in+=$v[0]; $cw+=$v[1]; $cr+=$v[2]; $out+=$v[3] }
  [pscustomobject]@{ In=$in; Out=$out; CR=$cr; CW=$cw }
}

# --- window ---
$pad=14; $barW=272; $W=$pad*2+$barW
$form = New-Object Windows.Forms.Form
$form.FormBorderStyle='None'; $form.TopMost=$true; $form.ShowInTaskbar=$false
$form.BackColor=[Drawing.Color]::FromArgb(24,25,28); $form.Opacity=1.0
$form.Size=New-Object Drawing.Size($W,300)
$form.StartPosition='Manual'
$wa=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location=New-Object Drawing.Point(($wa.Right-$W-16),($wa.Top+16))

$gray=[Drawing.Color]::FromArgb(150,152,158)
$white=[Drawing.Color]::FromArgb(235,236,238)
$track=[Drawing.Color]::FromArgb(48,50,56)
$blue=[Drawing.Color]::FromArgb(58,140,236)
$yellow=[Drawing.Color]::FromArgb(232,196,42)

function Lbl($text,$x,$y,$w,$align,$size,$style,$color) {
  $l=New-Object Windows.Forms.Label
  $l.Text=$text; $l.Location=New-Object Drawing.Point($x,$y); $l.Size=New-Object Drawing.Size($w,18)
  $l.Font=New-Object Drawing.Font('Segoe UI',$size,$style); $l.ForeColor=$color
  $l.TextAlign=$align; $l.BackColor=[Drawing.Color]::Transparent
  $form.Controls.Add($l); $l
}
function Bar($y,$color) {
  $t=New-Object Windows.Forms.Panel
  $t.Location=New-Object Drawing.Point($pad,$y); $t.Size=New-Object Drawing.Size($barW,6); $t.BackColor=$track
  $f=New-Object Windows.Forms.Panel
  $f.Location=New-Object Drawing.Point(0,0); $f.Size=New-Object Drawing.Size(0,6); $f.BackColor=$color
  $t.Controls.Add($f); $form.Controls.Add($t); $f
}

$null = Lbl 'Usage' $pad 10 100 'MiddleLeft' 10 'Bold' $white
$null = Lbl '5-hour limit' $pad 36 150 'MiddleLeft' 9 'Regular' $white
$r1info = Lbl '' $pad 36 $barW 'MiddleRight' 9 'Regular' $gray
$r1bar = Bar 60 $blue
$null = Lbl 'Weekly · all models' $pad 76 200 'MiddleLeft' 9 'Regular' $white
$r2info = Lbl '' $pad 76 $barW 'MiddleRight' 9 'Regular' $gray
$r2bar = Bar 100 $blue
$null = Lbl 'Sonnet only' $pad 116 150 'MiddleLeft' 9 'Regular' $white
$r3info = Lbl '' $pad 116 $barW 'MiddleRight' 9 'Regular' $gray
$r3bar = Bar 140 $blue

$null = Lbl 'This session' $pad 166 150 'MiddleLeft' 10 'Bold' $white
$rowDefs = @('Input','Output','Cache read','Cache write')
$sVals = @{}
$y=194
foreach ($name in $rowDefs) {
  $null = Lbl $name $pad $y 120 'MiddleLeft' 9 'Regular' $gray
  $sVals[$name] = Lbl '' $pad $y $barW 'MiddleRight' 9 'Regular' $white
  $y += 20
}

# drag to move; right-click to close
$script:drag=$false; $script:off=$null
$down={ if($_.Button -eq 'Left'){$script:drag=$true;$script:off=[Windows.Forms.Cursor]::Position} elseif($_.Button -eq 'Right'){$form.Close()} }
$move={ if($script:drag){$p=[Windows.Forms.Cursor]::Position; $form.Location=New-Object Drawing.Point(($form.Location.X+$p.X-$script:off.X),($form.Location.Y+$p.Y-$script:off.Y)); $script:off=$p} }
$up={ $script:drag=$false }
foreach($c in @($form)+@($form.Controls)){ $c.Add_MouseDown($down); $c.Add_MouseMove($move); $c.Add_MouseUp($up) }

# close button + always-on-top toggle (added after drag wiring)
$close=New-Object Windows.Forms.Label
$close.Text='X'; $close.Size=New-Object Drawing.Size(18,18); $close.Location=New-Object Drawing.Point(($W-24),6)
$close.Font=New-Object Drawing.Font('Segoe UI',9,'Bold'); $close.ForeColor=$gray
$close.TextAlign='MiddleCenter'; $close.BackColor=[Drawing.Color]::Transparent; $close.Cursor='Hand'
$close.Add_MouseEnter({ $close.ForeColor=[Drawing.Color]::FromArgb(235,90,90) })
$close.Add_MouseLeave({ $close.ForeColor=$gray }); $close.Add_Click({ $form.Close() })
$form.Controls.Add($close)
$pin=New-Object Windows.Forms.Label
$pin.Text='TOP'; $pin.Size=New-Object Drawing.Size(34,18); $pin.Location=New-Object Drawing.Point(($W-60),6)
$pin.Font=New-Object Drawing.Font('Segoe UI',8,'Bold'); $pin.TextAlign='MiddleCenter'
$pin.BackColor=[Drawing.Color]::Transparent; $pin.Cursor='Hand'; $pin.ForeColor=$blue
$pin.Add_Click({ $form.TopMost = -not $form.TopMost; $pin.ForeColor = if ($form.TopMost) { $blue } else { $gray } })
$form.Controls.Add($pin)

function SetRow($info,$bar,$util,$resetIso) {
  if ($null -eq $util) { $info.Text='—'; $bar.Width=0; return }
  $info.Text = (ResetText $resetIso) + '    ' + ('{0:N0}%' -f $util)
  $bar.Width = [int]([math]::Min(100,$util) * $barW / 100)
}
function Refresh {
  $u = Get-Usage
  if ($u) {
    SetRow $r1info $r1bar $u.five_hour.utilization        $u.five_hour.resets_at
    SetRow $r2info $r2bar $u.seven_day.utilization         $u.seven_day.resets_at
    SetRow $r3info $r3bar $u.seven_day_sonnet.utilization  $u.seven_day_sonnet.resets_at
  } else {
    $r1info.Text='auth? run Claude Code'; $r2info.Text=''; $r3info.Text=''
  }
  $s = Session-Breakdown
  $sVals['Input'].Text=Fmt $s.In; $sVals['Output'].Text=Fmt $s.Out
  $sVals['Cache read'].Text=Fmt $s.CR; $sVals['Cache write'].Text=Fmt $s.CW
}

$timer=New-Object Windows.Forms.Timer; $timer.Interval=15000
$timer.add_Tick({ Refresh })
$form.Add_Shown({ Refresh; $timer.Start() })
[Windows.Forms.Application]::Run($form)
